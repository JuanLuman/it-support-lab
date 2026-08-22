<#
    verificar-lab.ps1
    Verificacion rapida del lab lab.local
    Correr como Administrador. Detecta solo si esta en el DC o en el cliente.
#>

$ErrorActionPreference = "Continue"
$esDC = (Get-WmiObject Win32_ComputerSystem).DomainRole -ge 4

Write-Host "=== Equipo: $env:COMPUTERNAME ===" -ForegroundColor Cyan
Write-Host "Rol: $(if($esDC){'Domain Controller'}else{'Cliente / Miembro'})`n"

# --- Comun a los dos ---
Write-Host "--- Hora del sistema ---" -ForegroundColor Yellow
Get-Date
Write-Host "(Kerberos falla si hay mas de 5 min de diferencia entre DC y cliente)`n"

Write-Host "--- Configuracion de red ---" -ForegroundColor Yellow
Get-NetIPConfiguration | Where-Object { $_.IPv4Address } |
    Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway,
                  @{n='DNS';e={($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses -join ', '}} |
    Format-List

Write-Host "--- Dominio ---" -ForegroundColor Yellow
$cs = Get-WmiObject Win32_ComputerSystem
Write-Host "Dominio: $($cs.Domain)"
Write-Host "Unido al dominio: $($cs.PartOfDomain)`n"

if ($esDC) {
    Write-Host "--- Servicios criticos de AD ---" -ForegroundColor Yellow
    Get-Service NTDS, DNS, Netlogon, W32Time, KDC -ErrorAction SilentlyContinue |
        Select-Object Name, Status, StartType | Format-Table -AutoSize

    Write-Host "--- Dominio y roles FSMO ---" -ForegroundColor Yellow
    Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode,
        PDCEmulator, RIDMaster, InfrastructureMaster | Format-List

    Write-Host "--- Equipos en el dominio ---" -ForegroundColor Yellow
    Get-ADComputer -Filter * -Properties LastLogonDate |
        Select-Object Name, Enabled, LastLogonDate | Format-Table -AutoSize

    Write-Host "--- Usuarios ---" -ForegroundColor Yellow
    Get-ADUser -Filter * | Select-Object Name, SamAccountName, Enabled | Format-Table -AutoSize

    Write-Host "--- dcdiag (resumen) ---" -ForegroundColor Yellow
    dcdiag /q
    Write-Host "(Sin salida arriba = todos los tests OK)`n"
}
else {
    Write-Host "--- Canal seguro con el DC ---" -ForegroundColor Yellow
    $canal = Test-ComputerSecureChannel -Verbose
    if ($canal) {
        Write-Host "Canal seguro OK" -ForegroundColor Green
    } else {
        Write-Host "CANAL ROTO. Reparar con:" -ForegroundColor Red
        Write-Host '  Test-ComputerSecureChannel -Repair -Credential (Get-Credential lab\Administrator)'
    }

    Write-Host "`n--- Relacion de confianza (nltest) ---" -ForegroundColor Yellow
    nltest /sc_verify:lab.local

    Write-Host "`n--- DC que me esta atendiendo ---" -ForegroundColor Yellow
    nltest /dsgetdc:lab.local

    Write-Host "`n--- Resolucion DNS del dominio ---" -ForegroundColor Yellow
    Resolve-DnsName lab.local -Type A -ErrorAction SilentlyContinue |
        Select-Object Name, IPAddress | Format-Table -AutoSize
    Resolve-DnsName _ldap._tcp.dc._msdcs.lab.local -Type SRV -ErrorAction SilentlyContinue |
        Select-Object NameTarget, Port | Format-Table -AutoSize

    Write-Host "--- Tickets Kerberos ---" -ForegroundColor Yellow
    klist
}

Write-Host "`n=== Fin de la verificacion ===" -ForegroundColor Cyan
