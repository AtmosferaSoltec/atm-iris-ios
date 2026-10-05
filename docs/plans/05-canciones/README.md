# 05 · Canciones

## Objetivo

Que "Agregar al servicio › Letras" y el contador de la Biblioteca del Inicio usen la biblioteca real
de la iglesia (contrato §10), desde la copia local. En el iPad las canciones **solo se leen**: se
crean y editan en la web.

## Dependencias

Fase 02.

## Pasos

1. `LiveLibraryRepository.lyrics()`: canciones de la copia local, ordenadas por título (`nameKey`), mapeadas a `LyricSheet`
   (`sections` → `Slide(label:, content: .text(text, footnote: nil))`). `firstLine` sigue derivándose.
2. Búsqueda de `AddToServiceViewModel`: sigue siendo local; extiéndela para buscar también en el texto de las secciones
   (mismo criterio sin acentos).
3. Biblioteca vacía: en la pestaña Letras, estado vacío "Aún no hay canciones" / "Agrégalas desde la web de Iris."
4. Canción borrada en la web mientras está en la lista del servicio en curso: **no** se quita del servicio (la consola trabaja
   con lo que tenía); desaparece de la biblioteca en la siguiente sincronización.
5. `copyright` (si existe): se muestra debajo del autor en la fila de la biblioteca, en `caption` y `textTertiary`.

## Criterios de aceptación

- Con datos sincronizados: las canciones de la web aparecen en "Agregar al servicio" y se proyectan.
- `BuildProject` limpio; vistas previas sin cambios.

## Desviaciones

_(Completar al cerrar la fase.)_
