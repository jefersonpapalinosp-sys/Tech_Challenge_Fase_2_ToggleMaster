-- Chave fixa somente para desenvolvimento local.
-- Texto plano: tm_key_local_evaluation_service_dev_only
INSERT INTO api_keys (name, key_hash, is_active)
VALUES (
    'evaluation-service-local',
    '87e6c959f4118dfd606cdef341127ed1ba0251b0523993ea497f7e98d02e2f5a',
    true
)
ON CONFLICT (key_hash) DO NOTHING;
