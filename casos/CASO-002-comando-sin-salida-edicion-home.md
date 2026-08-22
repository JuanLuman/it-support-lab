# CASO-002 — Un comando de PowerShell no devuelve nada, sin error

**Fecha:** 22/08/2026
**Entorno:** Windows Home, notebook Intel Core i7-1360P, 16 GB RAM
**Categoría:** Software / Sistema operativo
**Tiempo de resolución:** ~10 minutos
**Estado:** Resuelto

**Síntoma reportado por el usuario:**
> "Ejecuté el comando y no me mostró nada, volvió como antes. No sé si funcionó o no."

---

## 1. Preguntas de encuadre

| Pregunta | Respuesta |
|---|---|
| ¿Desde cuándo pasa? | Primera vez que se ejecuta ese comando en este equipo |
| ¿A cuántos usuarios afecta? | Un equipo, un usuario |
| ¿Qué cambió recientemente? | Nada |
| ¿Funcionó alguna vez? | Sin datos previos |
| ¿Se puede reproducir a pedido? | Sí, comportamiento constante |

**Qué me dice el encuadre:** el dato relevante es lo que **no** apareció. No hubo mensaje de error, ni advertencia, ni excepción: solo el prompt de vuelta. Eso separa el caso de un fallo de sintaxis o de permisos, que sí habrían escrito algo en pantalla.

---

## 2. Hipótesis

| # | Hipótesis | Cómo la descarto | Costo de probarla |
|---|---|---|---|
| 1 | El comando se ejecutó sin privilegios suficientes | Repetir en una consola elevada y comparar | Bajo |
| 2 | Se pegó la línea incompleta y PowerShell quedó esperando | Revisar el historial de la consola con la flecha arriba | Bajo |
| 3 | El objeto consultado no existe en esta edición de Windows, y el filtro devuelve un conjunto vacío | Consultar la edición del producto y listar todos los features coincidentes en lugar de uno exacto | Bajo |

---

## 3. Diagnóstico ejecutado

### 3.1 — Comando original

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All | Select-Object State
```

```
PS C:\Users\jguti>
```

**Conclusión:** sin salida y sin error. En una ejecución anterior sin privilegios, el mismo comando había devuelto "La operación solicitada requiere elevación", así que la hipótesis 1 queda **descartada**: la consola estaba elevada y el comportamiento del error de permisos es distinto y visible.

### 3.2 — Hipótesis 2: línea incompleta

El comando aparece completo en el historial de la consola, en una sola línea, y el prompt volvió inmediatamente en lugar de quedar esperando continuación.

**Conclusión:** **descartada**.

### 3.3 — Hipótesis 3: edición del sistema operativo

```powershell
Get-ComputerInfo -Property WindowsProductName
```

```
WindowsProductName
------------------
Windows 10 Home
```

**Conclusión:** **confirmada**. La edición es Home. Hyper-V como rol completo no se distribuye en las ediciones Home de Windows, solo en Pro, Enterprise y Education. El feature `Microsoft-Hyper-V-All` simplemente no forma parte del catálogo de esa edición.

**Nota sobre el valor devuelto:** el nombre reporta "Windows 10" aun en equipos con Windows 11, porque la clave `ProductName` del registro se mantuvo por compatibilidad con software que la lee. Lo que sí es confiable de ese valor es la **edición** — Home — que es el dato que resuelve el caso.

---

## 4. Causa raíz

`Get-WindowsOptionalFeature -FeatureName` filtra sobre el catálogo de características de la edición instalada. Cuando el nombre solicitado no existe en ese catálogo, el resultado es un conjunto vacío.

**Por qué se produjo:** un conjunto vacío no es una condición de error. El cmdlet hizo su trabajo correctamente: buscó y no encontró. PowerShell pasa ese conjunto vacío por la tubería a `Select-Object`, que no tiene nada que formatear, y la consola no imprime nada. El silencio es la respuesta, no la ausencia de respuesta.

---

## 5. Solución aplicada

Reemplazar la consulta por nombre exacto con una por coincidencia parcial, que devuelve el catálogo real en lugar de fallar en silencio:

```powershell
Get-WindowsOptionalFeature -Online |
    Where-Object FeatureName -like "*Hyper-V*" |
    Select-Object FeatureName, State
```

Y confirmar la edición antes de asumir disponibilidad de cualquier característica:

```powershell
Get-ComputerInfo -Property WindowsProductName
```

**Solución de fondo vs. workaround:** de fondo. No se buscó un comando que devolviera algo, sino que se determinó por qué el original no tenía nada que devolver.

**Consecuencia para el proyecto:** al no haber Hyper-V en Home, el laboratorio se monta sobre otro hipervisor. Se optó por VMware Workstation Pro, gratuito para uso personal desde noviembre de 2024.

---

## 6. Verificación con el usuario

- **Qué le pedí que probara:** ejecutar la consulta por coincidencia parcial y el comando de edición del producto.
- **Resultado:** edición Home confirmada; ningún feature de Hyper-V disponible en el catálogo.
- **Confirmación de cierre:** sí. El usuario entendió que el equipo no tiene un problema, sino una limitación de licencia, y siguió con un hipervisor alternativo.

---

## 7. Prevención / qué documentaría en la KB

- **Prevención:** verificar la edición de Windows antes de planificar cualquier despliegue que dependa de características exclusivas de Pro o superior. Consultar catálogos con `-like` en lugar de nombres exactos cuando no hay certeza de que el objeto exista.
- **Artículo de KB propuesto:** *"Salida vacía en PowerShell: cómo distinguir 'no encontré nada' de 'algo falló'"*
  - Un conjunto vacío atraviesa la tubería sin generar error ni salida en pantalla.
  - `-FeatureName` con nombre exacto falla en silencio; `Where-Object ... -like` muestra el catálogo real.
  - Características exclusivas de Pro/Enterprise: Hyper-V, BitLocker, Directiva de grupo local, unión a dominio.
- **Ticket relacionado en GLPI:** pendiente de carga.

---

## 8. Qué aprendí

Interpreté la pantalla en blanco como "no pasó nada" cuando en realidad era un resultado, y uno bastante informativo. Un comando que vuelve al prompt sin escribir nada ya descartó varias cosas por su cuenta: no hubo error de sintaxis, no hubo excepción, no hubo problema de permisos.

Tampoco había verificado la edición del sistema operativo antes de planificar sobre una característica que depende de ella. Es un chequeo de diez segundos que habría evitado toda la secuencia.

Y algo que me sirve como método: cuando consulto un catálogo por nombre exacto y no encuentro, la siguiente consulta debería ser más amplia, no más específica. Buscar variantes del nombre exacto es insistir en el mismo camino; listar el catálogo entero muestra el terreno real.
