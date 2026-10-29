# Laboratorio de red aislado

Este laboratorio levanta tres contenedores Linux que pueden comunicarse entre sí en una red Docker interna. No monta directorios del host, no usa `--network host`, no pide modo privilegiado y limita CPU, memoria y procesos por contenedor.

La red interna no tiene salida a Internet. Docker asigna las direcciones y las MAC automáticamente; este laboratorio no falsifica identidades ni está diseñado para evadir límites, cuotas o bloqueos de OpenCode. OpenCode no se incluye en estos contenedores.

## Requisitos

- Docker Engine en ejecución.
- Docker Compose v2 (`docker compose`).

## Iniciar y comprobar

Desde esta carpeta:

```sh
docker compose up -d
docker compose ps
docker compose exec node1 nslookup node2
```

El último comando comprueba la resolución DNS entre nodos en la red interna.

## Detener y eliminar

```sh
docker compose down
```

No se crean volúmenes persistentes ni se modifican archivos del host. Las imágenes descargadas permanecen en la caché de Docker.
