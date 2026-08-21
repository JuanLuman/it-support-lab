# it-support-lab

Laboratorio personal de soporte IT: casos de diagnóstico documentados con una metodología fija, sobre un entorno Windows Server / Active Directory montado desde cero.

El objetivo no es acumular casos resueltos, sino dejar registro del **razonamiento**: qué hipótesis se plantearon antes de tocar nada, cómo se descartaron, y qué se aprendió cuando el primer diagnóstico fue el equivocado.

---

## Metodología

Cada caso sigue el mismo formato de ocho secciones ([`casos/TEMPLATE-CASO.md`](casos/TEMPLATE-CASO.md)):

1. Preguntas de encuadre — alcance y cambios recientes, antes de cualquier comando
2. Hipótesis — mínimo tres, con el método de descarte y su costo definidos **antes** del diagnóstico
3. Diagnóstico ejecutado — comando, salida, conclusión
4. Causa raíz — una sola frase, y el mecanismo detrás
5. Solución aplicada — pasos reproducibles por otra persona
6. Verificación con el usuario
7. Prevención y artículo de KB propuesto
8. Qué aprendí — incluidos los errores de método

La regla que sostiene todo esto: **la sección 2 se completa antes que la 3.** Escribir las hipótesis sabiendo ya la respuesta convierte el documento en una narración, no en un registro.

---

## Índice de casos

| Caso | Síntoma | Categoría | Causa raíz |
|---|---|---|---|
| [CASO-001](casos/CASO-001-virtualizacion-reporta-false.md) | El sistema reporta que la virtualización está deshabilitada | Hardware / Virtualización | Un hipervisor activo toma control de VT-x y WMI deja de exponerlo |

---

## Entorno del laboratorio

| Equipo | Rol | Sistema |
|---|---|---|
| `SRV-DC01` | Controlador de dominio, DNS | Windows Server 2022 Standard (Desktop Experience) |
| `PC-LAB-01` | Cliente unido al dominio | Windows 11 |

- **Dominio:** `lab.local`
- **Hipervisor:** Hyper-V sobre Windows 11
- **Mesa de ayuda:** GLPI en contenedor Docker

### Scripts

- [`scripts/verificar-lab.ps1`](scripts/verificar-lab.ps1) — verificación del estado del dominio. Detecta si corre en el DC o en el cliente y ajusta los chequeos: servicios de AD, roles FSMO y `dcdiag` en el servidor; canal seguro, registros SRV y tickets Kerberos en el cliente.

---

## Estado

En construcción. Registro de avance en la sección de commits.

---

**Juan Gutiérrez Luman** — [LinkedIn](https://www.linkedin.com/in/juangutierrezluman)
Analista en Tecnologías de la Información (en curso) — Universidad de la Empresa, Montevideo
