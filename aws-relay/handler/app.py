import json
import os
import time
import logging

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CONNECTIONS_TABLE = os.environ["CONNECTIONS_TABLE"]
PAIRS_TABLE = os.environ["PAIRS_TABLE"]
CONNECTION_MAP_TABLE = os.environ["CONNECTION_MAP_TABLE"]

dynamodb = boto3.resource("dynamodb")
connections_table = dynamodb.Table(CONNECTIONS_TABLE)
pairs_table = dynamodb.Table(PAIRS_TABLE)
connection_map_table = dynamodb.Table(CONNECTION_MAP_TABLE)

TTL_SECONDS = 86400  # 24 hours


def _apigw_client(event):
    domain = event["requestContext"]["domainName"]
    stage = event["requestContext"]["stage"]
    endpoint = f"https://{domain}/{stage}"
    return boto3.client("apigatewaymanagementapi", endpoint_url=endpoint)


def _send(apigw, connection_id, data):
    try:
        apigw.post_to_connection(
            ConnectionId=connection_id, Data=json.dumps(data).encode()
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "GoneException":
            _cleanup_connection(connection_id)
            return False
        raise
    return True


def _send_error(apigw, connection_id, message):
    _send(apigw, connection_id, {"type": "error", "message": message})


def _disconnect_connection(apigw, connection_id):
    try:
        apigw.delete_connection(ConnectionId=connection_id)
    except ClientError:
        pass


def _cleanup_connection(connection_id):
    resp = connection_map_table.get_item(Key={"connection_id": connection_id})
    item = resp.get("Item")
    if not item:
        return
    session_id = item["session_id"]
    _cleanup_session(session_id, connection_id)


def _cleanup_session(session_id, connection_id):
    connections_table.delete_item(Key={"session_id": session_id})
    connection_map_table.delete_item(Key={"connection_id": connection_id})

    resp = pairs_table.get_item(Key={"session_id": session_id})
    pair = resp.get("Item")
    if pair:
        peer_id = pair["peer_session_id"]
        pairs_table.delete_item(Key={"session_id": session_id})
        pairs_table.delete_item(Key={"session_id": peer_id})
        return peer_id
    return None


def _get_session_id(connection_id):
    resp = connection_map_table.get_item(Key={"connection_id": connection_id})
    item = resp.get("Item")
    return item["session_id"] if item else None


def _get_connection_id(session_id):
    resp = connections_table.get_item(Key={"session_id": session_id})
    item = resp.get("Item")
    return item["connection_id"] if item else None


# --- Route handlers ---


def handle_connect(event):
    return {"statusCode": 200}


def handle_disconnect(event):
    connection_id = event["requestContext"]["connectionId"]
    apigw = _apigw_client(event)

    session_id = _get_session_id(connection_id)
    if not session_id:
        return {"statusCode": 200}

    peer_id = _cleanup_session(session_id, connection_id)

    if peer_id:
        peer_conn = _get_connection_id(peer_id)
        if peer_conn:
            _send(apigw, peer_conn, {"type": "unpaired", "reason": "peer disconnected"})

    return {"statusCode": 200}


def handle_register(event, body):
    connection_id = event["requestContext"]["connectionId"]
    apigw = _apigw_client(event)

    session_id = body.get("session_id")
    if not session_id:
        _send_error(apigw, connection_id, "session_id required in register frame")
        return {"statusCode": 400}

    existing = connections_table.get_item(Key={"session_id": session_id}).get("Item")
    if existing and existing["connection_id"] != connection_id:
        old_conn = existing["connection_id"]
        _send(apigw, old_conn, {"type": "error", "message": "replaced by new connection"})
        _disconnect_connection(apigw, old_conn)
        connection_map_table.delete_item(Key={"connection_id": old_conn})

    now = int(time.time())
    connections_table.put_item(
        Item={
            "session_id": session_id,
            "connection_id": connection_id,
            "connected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "ttl": now + TTL_SECONDS,
        }
    )
    connection_map_table.put_item(
        Item={"connection_id": connection_id, "session_id": session_id}
    )

    _send(apigw, connection_id, {"type": "registered", "session_id": session_id})
    logger.info("Registered session %s on connection %s", session_id, connection_id)
    return {"statusCode": 200}


def handle_pair(event, body):
    connection_id = event["requestContext"]["connectionId"]
    apigw = _apigw_client(event)

    session_id = _get_session_id(connection_id)
    if not session_id:
        _send_error(apigw, connection_id, "not registered")
        return {"statusCode": 400}

    peer_session_id = body.get("peer_session_id")
    if not peer_session_id:
        _send_error(apigw, connection_id, "peer_session_id required")
        return {"statusCode": 400}

    peer_conn = _get_connection_id(peer_session_id)
    if not peer_conn:
        _send_error(apigw, connection_id, f"session {peer_session_id} not found")
        return {"statusCode": 400}

    existing_pair = pairs_table.get_item(Key={"session_id": session_id}).get("Item")
    if existing_pair:
        old_peer = existing_pair["peer_session_id"]
        pairs_table.delete_item(Key={"session_id": session_id})
        pairs_table.delete_item(Key={"session_id": old_peer})
        old_peer_conn = _get_connection_id(old_peer)
        if old_peer_conn:
            _send(
                apigw,
                old_peer_conn,
                {"type": "unpaired", "reason": "peer paired with another session"},
            )

    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    pairs_table.put_item(
        Item={
            "session_id": session_id,
            "peer_session_id": peer_session_id,
            "paired_at": now,
        }
    )
    pairs_table.put_item(
        Item={
            "session_id": peer_session_id,
            "peer_session_id": session_id,
            "paired_at": now,
        }
    )

    _send(apigw, peer_conn, {"type": "paired", "peer_session_id": session_id})
    _send(apigw, connection_id, {"type": "paired", "peer_session_id": peer_session_id})

    logger.info("Paired %s <-> %s", session_id, peer_session_id)
    return {"statusCode": 200}


def handle_unpair(event, body):
    connection_id = event["requestContext"]["connectionId"]
    apigw = _apigw_client(event)

    session_id = _get_session_id(connection_id)
    if not session_id:
        _send_error(apigw, connection_id, "not registered")
        return {"statusCode": 400}

    existing_pair = pairs_table.get_item(Key={"session_id": session_id}).get("Item")
    if existing_pair:
        peer_id = existing_pair["peer_session_id"]
        pairs_table.delete_item(Key={"session_id": session_id})
        pairs_table.delete_item(Key={"session_id": peer_id})
        peer_conn = _get_connection_id(peer_id)
        if peer_conn:
            _send(apigw, peer_conn, {"type": "unpaired", "reason": "peer disconnected"})

    _send(apigw, connection_id, {"type": "unpaired", "reason": "you disconnected"})
    return {"statusCode": 200}


def handle_message(event, body):
    connection_id = event["requestContext"]["connectionId"]
    apigw = _apigw_client(event)

    session_id = _get_session_id(connection_id)
    if not session_id:
        _send_error(apigw, connection_id, "not registered")
        return {"statusCode": 400}

    pair = pairs_table.get_item(Key={"session_id": session_id}).get("Item")
    if not pair:
        _send_error(apigw, connection_id, "not paired")
        return {"statusCode": 400}

    peer_id = pair["peer_session_id"]
    peer_conn = _get_connection_id(peer_id)
    if not peer_conn:
        _send_error(apigw, connection_id, "peer session gone")
        return {"statusCode": 400}

    raw_body = event.get("body", "")
    try:
        apigw.post_to_connection(
            ConnectionId=peer_conn, Data=raw_body.encode() if isinstance(raw_body, str) else raw_body
        )
        success = True
    except ClientError as e:
        if e.response["Error"]["Code"] == "GoneException":
            _cleanup_connection(peer_conn)
            success = False
        else:
            raise
    if not success:
        _send_error(apigw, connection_id, "peer session gone")

    return {"statusCode": 200}


# --- Main dispatcher ---

FRAME_HANDLERS = {
    "register": handle_register,
    "pair": handle_pair,
    "unpair": handle_unpair,
    "message": handle_message,
}


def handler(event, context):
    route_key = event["requestContext"].get("routeKey")

    if route_key == "$connect":
        return handle_connect(event)

    if route_key == "$disconnect":
        return handle_disconnect(event)

    raw_body = event.get("body")
    if not raw_body:
        return {"statusCode": 400}

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return {"statusCode": 400}

    frame_type = body.get("type")
    frame_handler = FRAME_HANDLERS.get(frame_type)

    if frame_handler:
        return frame_handler(event, body)

    connection_id = event["requestContext"]["connectionId"]
    apigw = _apigw_client(event)
    _send_error(apigw, connection_id, f"unexpected frame type: {frame_type}")
    return {"statusCode": 400}
