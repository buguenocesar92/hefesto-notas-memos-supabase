# Integraciones y portabilidad
Memos ofrece API documentada por versión. Para n8n/Laravel usar HTTPS y cuenta dedicada, token en gestor de secretos de backend, nunca en frontend público ni JSON exportado. Confirmar permisos y vencimiento de token en la versión instalada; un token de propietario da acceso excesivo.

Caso inicial: registrar una bitácora después de un despliegue, con referencia de proyecto y resultado sin credenciales. Crear nota privada, probar lectura por usuario autorizado y rechazo con otro usuario. Gestionar duplicados y reintentos en el emisor: este kit no instala automatizaciones en sistemas existentes.

Ejemplos Markdown se copian manualmente: no ejecutan importaciones ni crean datos. Para adjuntos usar API/función nativa y no insertar rutas externas de otros usuarios.

Sin IA configurada: notas y búsqueda usan funciones nativas. Activar un proveedor futuro puede enviar contenido fuera de la instancia; definir alcance antes de configurarlo. No se necesita una API de IA para desplegar este kit.
