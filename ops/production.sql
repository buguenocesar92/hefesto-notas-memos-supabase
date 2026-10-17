-- Read-only validation. Initial account and settings are configured through UI.
DO $$
BEGIN
 IF to_regclass('public.system_setting') IS NULL OR to_regclass('public."user"') IS NULL THEN
  RAISE EXCEPTION 'Complete alta privada antes de publicar';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public."user" WHERE role='HOST' AND row_status='NORMAL') THEN
  RAISE EXCEPTION 'Falta propietario activo';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.system_setting WHERE name='GENERAL'
  AND value::jsonb->>'disallowUserRegistration'='true') THEN
  RAISE EXCEPTION 'Cerrar registro de usuarios desde ajustes';
 END IF;
 -- PRIVATE is upstream default when ACCESS is absent or unspecified.
 IF EXISTS(SELECT 1 FROM public.system_setting WHERE name='ACCESS'
  AND COALESCE(value::jsonb->>'accessMode','INSTANCE_ACCESS_MODE_PRIVATE')
  NOT IN ('INSTANCE_ACCESS_MODE_PRIVATE','INSTANCE_ACCESS_MODE_UNSPECIFIED')) THEN
  RAISE EXCEPTION 'Configurar instancia privada';
 END IF;
END $$;
