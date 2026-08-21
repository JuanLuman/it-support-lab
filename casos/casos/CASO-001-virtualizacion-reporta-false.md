# CASO-001 — El sistema reporta que la virtualización está deshabilitada

**Fecha:** 21/08/2026
**Entorno:** Windows 11, notebook Intel Core i7-1360P (13ª gen), 16 GB RAM, SSD NVMe
**Categoría:** Hardware / Virtualización
**Tiempo de resolución:** ~15 minutos
**Estado:** Resuelto

**Síntoma reportado por el usuario:**
> "Quiero armar un laboratorio con máquinas virtuales, pero el chequeo previo me dice que la virtualización está en falso. ¿Tengo que entrar a la BIOS?"

---

## 1. Preguntas de encuadre

| Pregunta | Respuesta |
|---|---|
| ¿Desde cuándo pasa? | Detectado en el primer chequeo; no hay histórico previo |
| ¿A cuántos usuarios afecta? | Un equipo, un usuario |
| ¿Qué cambió recientemente? | Nada; equipo en uso normal |
| ¿Funcionó alguna vez? | Sin datos — nunca se corrieron VMs en este equipo |
| ¿Se puede reproducir a pedido? | Sí, el comando devuelve el mismo valor siempre |

**Qué me dice el encuadre:** alcance mínimo y sin cambio disparador. Al no haber un "antes que funcionaba", no hay regresión que buscar: el foco pasa a ser si el valor reportado significa realmente lo que aparenta.

---

## 2. Hipótesis

| # | Hipótesis | Cómo la descarto | Costo de probarla |
|---|---|---|---|
| 1 | VT-x deshabilitado en el firmware UEFI | Administrador de tareas → Rendimiento → CPU → campo "Virtualización" | Bajo |
| 2 | El procesador no soporta virtualización por hardware | Verificar especificaciones del modelo i7-1360P | Bajo |
| 3 | Hay un hipervisor activo que tomó control de VT-x, y por eso WMI deja de exponerlo | `Get-ComputerInfo -Property "HyperV*"` → revisar `HypervisorPresent` | Bajo |

**Nota de método:** las tres hipótesis son de costo bajo, así que el orden lo define la probabilidad, no el esfuerzo. La hipótesis 1 era la intuitiva y resultó equivocada — se registra igual, porque el descarte es parte del diagnóstico.

---

## 3. Diagnóstico ejecutado

### 3.1 — Lectura inicial que originó el caso

```powershell
Get-CimInstance Win32_Processor | Select-Object Name, VirtualizationFirmwareEnabled
```

```
Name                                  VirtualizationFirmwareEnabled
----                                  -----------------------------
13th Gen Intel(R) Core(TM) i7-1360P                           False
```

**Conclusión:** valor sospechoso. Un i7 de 13ª generación soporta VT-x sin excepción, lo que descarta la hipótesis 2 de entrada y hace poco creíble la 1 en un equipo de fábrica.

### 3.2 — Hipótesis 1: firmware (verificación por vía independiente)

Administrador de tareas → pestaña Rendimiento → CPU:

```
Virtualización: Habilitado
Núcleos: 12    Procesadores lógicos: 16
```

**Conclusión:** hipótesis 1 **descartada**. La virtualización está habilitada. Dos fuentes del mismo sistema operativo se contradicen, así que el problema no es el hardware sino la interpretación del indicador.

### 3.3 — Hipótesis 3: hipervisor activo

```powershell
Get-ComputerInfo -Property "HyperV*"
```

```
HyperVisorPresent                              : True
HyperVRequirementDataExecutionPreventionAvailable :
HyperVRequirementSecondLevelAddressTranslation    :
HyperVRequirementVirtualizationFirmwareEnabled    :
HyperVRequirementVMMonitorModeExtensions          :
```

**Conclusión:** hipótesis 3 **confirmada**. Hay un hipervisor corriendo. Los cuatro campos `HyperVRequirement*` aparecen vacíos precisamente por eso: son requisitos de instalación que Windows deja de evaluar cuando el hipervisor ya está activo. El vacío no indica ausencia, indica que la pregunta dejó de aplicar.

---

## 4. Causa raíz

`Win32_Processor.VirtualizationFirmwareEnabled` devuelve `False` cuando un hipervisor ya tomó control de las extensiones VT-x.

**Por qué se produjo:** con Hyper-V o VBS (Virtualization-Based Security) activos, Windows corre sobre el hipervisor y VT-x queda administrado por esa capa. La propiedad no responde "¿está habilitada la virtualización?" sino "¿el firmware la expone directamente al sistema operativo?". Con un hipervisor de por medio, la respuesta legítima a esa segunda pregunta es que no.

---

## 5. Solución aplicada

No hubo nada que corregir: el sistema estaba correcto y la lectura era la equivocada. Lo que se corrigió fue el método de verificación:

1. No usar `Win32_Processor.VirtualizationFirmwareEnabled` como indicador de disponibilidad de virtualización.
2. Verificar por Administrador de tareas → Rendimiento → CPU → "Virtualización".
3. Ante contradicción entre indicadores, consultar `Get-ComputerInfo -Property "HyperV*"` para determinar si hay un hipervisor en el medio.

**Solución de fondo vs. workaround:** de fondo. Se identificó qué mide realmente cada indicador, en lugar de buscar uno que devolviera el valor esperado.

---

## 6. Verificación con el usuario

- **Qué le pedí que probara:** abrir el Administrador de tareas y leer el campo "Virtualización" en la pestaña Rendimiento.
- **Resultado:** "Habilitado".
- **Confirmación de cierre:** sí. El equipo quedó habilitado para montar el laboratorio sin reiniciar a UEFI.

---

## 7. Prevención / qué documentaría en la KB

- **Prevención:** incorporar la verificación por Administrador de tareas al checklist previo de cualquier despliegue de virtualización, y no depender de una sola consulta WMI.
- **Artículo de KB propuesto:** *"Verificar soporte de virtualización en Windows 11: qué indicador usar y por qué WMI puede engañar"*
  - `VirtualizationFirmwareEnabled` reporta `False` con un hipervisor activo; no es un fallo del equipo.
  - La verificación confiable es Administrador de tareas → Rendimiento → CPU.
  - `HypervisorPresent: True` explica la discrepancia y evita un reinicio innecesario a UEFI.
- **Ticket relacionado en GLPI:** pendiente de carga.

---

## 8. Qué aprendí

Le di más peso al indicador con el nombre más parecido a la pregunta que quería responder, y casi mando a alguien a la BIOS por eso. El nombre de un campo describe la intención de quien lo programó, no necesariamente lo que mide en cada contexto.

También aprendí a leer los campos vacíos. Mi primer impulso fue tratarlos como datos faltantes, cuando en realidad eran la pista más fuerte: Windows había dejado de evaluar esos requisitos porque ya no correspondían.

Y lo más útil como método: cuando el costo de descartar una hipótesis es bajo, conviene verificar por una segunda vía **antes** de actuar. Diez segundos en el Administrador de tareas contra un reinicio a UEFI y varios minutos buscando una opción que ya estaba habilitada.
