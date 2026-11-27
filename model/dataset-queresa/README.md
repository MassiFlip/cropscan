# Dataset de fruto de palta para CropScan

El objetivo es reunir 300 fotos sanas y 300 con queresa. Este directorio incluye 94 fotos sanas y 6 con queresa. Hay 252 fotos sanas de palta Fuerte adicionales disponibles en su fuente original. En total se han reunido 346 fotos sanas y 6 con queresa. Siguen pendientes 294 positivas.

El [manifiesto](manifest.csv) indica la fuente, la etiqueta original, la variedad y el lugar cuando se conocen, la autoría, la licencia y el SHA-256 de las fotos incluidas. Ninguna está confirmada como palta Naval de Huaral. El lote es exploratorio y todavía no cubre la validación de campo del MVP.

## Fotos incluidas

- **87 frutos sanos** de Luis Alberto Castillo Sanabria y Jesús Enrique Flores Riera, [Agrocomputation 227](https://huggingface.co/datasets/jf-floresriera/agrocomputation_227_avocado_rgb_luis_castillo), bajo [Artistic-2.0](licencias/Artistic-2.0.txt). Se conservaron los bytes de las fotos seleccionadas de la clase Sano. Se descartaron duplicados y dos archivos con etiquetas contradictorias.
- **7 frutos clasificados visualmente como Good** por Anjali Sharma, [Harvard Dataverse](https://doi.org/10.7910/DVN/Q1QO33), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
- **1 fruto con queresa** de A. M. Varela, icipe, [Infonet Biovision](https://infonet-biovision.org/PlantHealth/MinorPests/Scales-3), [CC BY-NC-SA según las condiciones de Infonet](https://infonet-biovision.org/license). Se mantiene la fotografía original.
- **3 fotos de frutos Hass con queresa en Casma** de Víctor Máximo Maguiña Chinchay y Ricardo Jesús Marcelo Cruz, [Universidad Nacional del Santa](https://repositorio.uns.edu.pe/handle/20.500.14278/4030?show=full), [CC BY-NC-ND 3.0 US](https://creativecommons.org/licenses/by-nc-nd/3.0/us/). Son los archivos incrustados sin editar del anexo 1, página 153.
- **1 fruto Hass con queresa en Motupe** de Luz Madani Coronado Tuñoque y María Belú Sandoval Raymundo, [Universidad Nacional Pedro Ruiz Gallo](https://repositorio.unprg.edu.pe/handle/20.500.12893/9602?show=full), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Se extrajo la foto 22 de la página 145.
- **1 fruto con queresa en blanco y negro** de A. R. Brimblecombe, [Departamento de Agricultura de Queensland](https://era.dpi.qld.gov.au/id/eprint/13249/). Es un recorte de la figura 9, página 51, de 1968. [El copyright estatal para obras anteriores a 1969 ha expirado](https://www.qld.gov.au/recreation/arts/heritage/archives/research-guides-resources/copying).

## Fotos sanas de Chapingo

[fuente-chapingo.csv](fuente-chapingo.csv) identifica 252 fotos marcadas como Healthy en el [dataset de Ulises Enrique Campos-Ferreira](https://www.kaggle.com/datasets/camposfe1/clasifiacin-de-enfermedades-del-aguacatero). Se eligió una por grupo de aumentos. Las fotos se obtienen del archivo publicado por el autor, buscando los miembros del ZIP indicados en la columna original. El archivo de origen conserva el copyright de los autores.
