# vicasa-media-meta-assets

Repositorio **de tránsito** para subir artes publicitarios de VICASA a Meta Ads por URL.

- Es **público**: todo lo que se sube aquí es visible para cualquiera mientras exista.
- Cada arte se sube a una rama temporal con nombre aleatorio, Meta lo descarga por su URL raw
  y la rama se borra al terminar. `main` no guarda artes.
- Borrar la rama no limpia de inmediato el historial de Git: el archivo puede seguir accesible
  por su SHA durante un tiempo. No subir arte confidencial ni de productos sin lanzar.

## Uso

Requisitos: macOS (`sips`) o Linux con Python 3 y Pillow (`pip install pillow`). El script elige solo.

```bash
scripts/upload_to_meta_url.sh push <ruta-del-arte> <marca>   # sube e imprime la URL raw
scripts/upload_to_meta_url.sh cleanup <rama>                 # borra la rama tras cargar a Meta
scripts/upload_to_meta_url.sh list                           # ramas temporales vivas
```

Marcas (una carpeta por marca): `wells`, `farolazo`, `presidente`, `gran-ninot`, `vivaldi`,
`zenka`, `los-reyes`, `cardenal`, `castellana`, `madrilena`, `brisa`, `guardatodo`,
`marsala-la-granja`.
