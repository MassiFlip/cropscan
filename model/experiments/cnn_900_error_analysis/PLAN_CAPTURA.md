# Fotos adicionales para el siguiente experimento

Priorizar palta Naval de Huaral con autorización, variedad documentada y evaluación de un especialista. Capturar ambas clases en cada entorno disponible para que la clase no coincida sistemáticamente con un fondo, cámara o sesión. El objetivo histórico es reunir al menos 300 originales etiquetados por clase, con suficientes frutos y parcelas independientes. Una ráfaga o varias vistas del mismo fruto se registran como un grupo.

| Prioridad | Fotografías que conviene recopilar | Control de captura |
| --- | --- | --- |
| 1 | Frutos Naval con queresa confirmada en distintos frutos, árboles, parcelas y fechas, con una vista general y una vista cercana que muestre los signos. Incluir los grados de visibilidad que valide el especialista. | Tomar vistas de frutos sanos confirmados en las mismas sesiones, con cámaras, distancia y condiciones de luz comparables. Registrar el órgano afectado y la evidencia de la etiqueta. |
| 1 | Frutos Naval sanos confirmados en campo con superficies verdes, oscuras o pardas y diferentes niveles de rugosidad. Incluir los que tengan rasgos normales o marcas no atribuibles a queresa, según el especialista. | Conservar ejemplos con piel clara y oscura, textura lisa y rugosa, en fondos que también aparezcan entre los positivos. |
| 2 | Ambas clases con follaje, tierra, fondo neutro y fruto sostenido en la mano. Capturar luz difusa, sol lateral, sombra y reflejos moderados. | Mantener condiciones equivalentes dentro de cada sesión. Registrar fondo y luz como metadatos observables. |
| 2 | Fotos de ambas clases con varias cámaras Android, a distancia habitual de uso y en distintos encuadres. Incluir piel ocupando distinta proporción de la imagen y signos pequeños que aún se distingan. | Conservar la foto original y registrar resolución y distancia aproximada. Fotografiar el mismo fruto en distintas vistas cuando sirva para documentar su etiqueta. |
| 3 | Tomas con movimiento, contraluz fuerte, fruto lejano, desenfoque o recortes extremos para probar el control de calidad. | Guardarlas en un lote de control aparte o con calidad desaprobada. Conservar su evaluación agronómica si existe y excluirlas del conjunto principal de desempeño. |
| Según alcance del MVP | Si la CNN también debe recibir hojas, recopilar hojas sanas y con queresa confirmada de Naval en los mismos entornos. | Registrar `organo=hoja` y reportar las métricas por órgano. Evitar que el tipo de órgano sustituya a la etiqueta. |

Campos por toma: identificador de foto, fruto, árbol, sesión, parcela y fecha, variedad, órgano, etiqueta y revisor, permiso, dispositivo, resolución, iluminación, fondo y calidad. En positivos registrar una vista clara de la zona indicada por el especialista y vincularla al mismo fruto.

Reservar nuevas parcelas o unidades productivas completas para validación y prueba antes de generar aumentos. Mantener el conjunto de prueba de la corrida 01 como referencia histórica. El siguiente ajuste de hiperparámetros o umbral debe usar una validación nueva, con ambas clases y suficientes positivos independientes.

## Registro de la salida a campo

Copia la [plantilla CSV](REGISTRO_CAMPO.csv) al directorio del nuevo lote y agrega una fila por fotografía original. `photo` es la ruta relativa al CSV. Registra `unit` como código estable de parcela, junto con `tree_id`, `fruit_id` y `session_id`. Mantén el mismo `fruit_id` en todas las vistas del mismo fruto y conserva los mismos códigos de parcela y árbol si vuelves otro día. Registra la fecha y hora en `captured_at` y los datos de cámara, luz, fondo y vista en `device`, `lighting`, `background` y `view`.

En cada sesión, empieza por los positivos que confirme el especialista y captura sanas de la misma parcela y con condiciones equivalentes. Registra el permiso en `permission_ref` y la variedad confirmada en `cultivar`. El agrónomo documenta la condición en `condition`, su revisión en `validation_status`, su identificación en `reviewer`, la fecha en `reviewed_on` y la referencia de la evidencia en `evidence_ref`. Mantén `label` vacía mientras la revisión esté pendiente o sea inconclusa. Una vez confirmada, usa `possible_scale` para queresa y `no_visible_signs` para las sanas según el contrato de entrenamiento. Completa `quality_ok` tras revisar nitidez, encuadre y trazabilidad. Asigna `split` por parcela una vez cerrado el lote.

Reporta por separado fotografías, frutos únicos por condición, árboles y parcelas. Las 22 fotos HEIC pendientes parecen corresponder al mismo fruto. Si la revisión lo confirma, se contabilizan como un solo fruto incluso si todas resultan utilizables.

## Coordinación en Huaral

- **Agencia Agraria Huaral**, `agencia.huaral@dral.regionlima.gob.pe`. Solicitar el contacto de productores con Naval y autorización para fotografiar frutos de ambas condiciones dentro de una misma parcela. [Directorio oficial de Agricultura Lima](https://www.gob.pe/institucion/regionlima-dra/funcionarios)
- **INIA, Estación Experimental Agraria Donoso**, `donoso@inia.gob.pe`. Solicitar orientación y disponibilidad de un especialista en frutales o manejo de plagas para validar las etiquetas durante la salida. [Sede oficial](https://www.gob.pe/institucion/inia/sedes?sheet=2) · [Equipo de capacitación en palto](https://www.gob.pe/institucion/inia/campa%C3%B1as/141546-curso-virtual-manejo-integrado-del-cultivo-de-palto)

El informe municipal de Huaral documenta visitas a cultivos de palta Naval en Huando en 2024. Es una referencia para consultar por parcelas activas y disponibilidad de frutos. [Informe municipal](https://cdn.www.gob.pe/uploads/document/file/7004579/6029606-documentos-o-informes-presentados-de-la-segunda-audiencia-publica-de-rendicion-de-cuentas-2024.pdf?v=1727444240)
