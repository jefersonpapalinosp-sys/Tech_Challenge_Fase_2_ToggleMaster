"""Envia um lote grande de eventos sinteticos ao SQS, em paralelo, para gerar carga no analytics-service.

Uso (depois de 01-preparar-sessao.ps1 no mesmo terminal):
    $envio = python .\\apresentacao\\scripts\\04-carga-analytics-sqs.py --count 6000 | ConvertFrom-Json
O progresso sai no stderr; o resumo (RunId, MessagesSent, Queue) sai no stdout em JSON.
"""
import argparse
import json
import os
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

ACCOUNT = "533267349027"
QUEUE = "tgmqueue"
REGION = "us-east-1"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=6000)
    parser.add_argument("--threads", type=int, default=8)
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()
    if not 1 <= args.count <= 20000:
        sys.exit("--count deve ficar entre 1 e 20000.")

    run_id = "video-hpa-" + datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S") + "-" + uuid.uuid4().hex[:6]
    if args.preview:
        print(json.dumps({"Preview": True, "Queue": QUEUE, "Count": args.count, "RunId": run_id, "WritesExecuted": 0}))
        return

    if not os.environ.get("AWS_SESSION_TOKEN"):
        sys.exit("Sem credenciais neste terminal: rode o bloco 00 (01-preparar-sessao.ps1) antes.")
    import boto3
    from botocore.config import Config

    session = boto3.Session(region_name=REGION)
    if session.client("sts").get_caller_identity()["Account"] != ACCOUNT:
        sys.exit("Prepare a sessao com 01-preparar-sessao.ps1.")
    sqs = session.client("sqs", config=Config(max_pool_connections=args.threads * 2))
    queue_url = sqs.get_queue_url(QueueName=QUEUE)["QueueUrl"]
    if not queue_url.endswith(f"/{ACCOUNT}/{QUEUE}"):
        sys.exit("Fila diferente do destino esperado.")
    print(f"RunId={run_id} (usar como filtro flag_name no DynamoDB)", file=sys.stderr, flush=True)

    def send_batch(offset):
        entries = []
        for j in range(offset, min(offset + 10, args.count)):
            body = {"user_id": f"synthetic-video-{j}", "flag_name": run_id, "result": True,
                    "timestamp": datetime.now(timezone.utc).isoformat()}
            entries.append({"Id": f"event-{j}", "MessageBody": json.dumps(body)})
        response = sqs.send_message_batch(QueueUrl=queue_url, Entries=entries)
        if response.get("Failed"):
            raise RuntimeError(f"Falha parcial no lote {offset}: {response['Failed'][0]}")
        return len(response.get("Successful", []))

    sent, start = 0, time.time()
    with ThreadPoolExecutor(args.threads) as pool:
        for future in as_completed([pool.submit(send_batch, o) for o in range(0, args.count, 10)]):
            sent += future.result()
            if sent % 500 == 0 or sent == args.count:
                print(f"Mensagens aceitas: {sent}/{args.count}", file=sys.stderr, flush=True)

    print(json.dumps({"RunId": run_id, "MessagesSent": sent, "Queue": QUEUE,
                      "Seconds": round(time.time() - start, 1)}))


if __name__ == "__main__":
    main()
