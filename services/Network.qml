pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import "../config" as Config

// Network state through NetworkManager: the cable, the Wi-Fi adapter and its
// networks, and the icon that follows the connection and the signal.
Singleton {
    id: root
    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(device => device.type === DeviceType.Wired && device.connected) ?? null
    readonly property var wifi: devices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property var networks: (wifi?.networks?.values ?? []).slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (strength(b) - strength(a)))
    readonly property var activeWifi: networks.find(network => network.connected) ?? null
    readonly property string kind: wired ? "wired" : activeWifi ? "wifi" : "offline"
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full
        || (Networking.connectivity === NetworkConnectivity.Unknown && kind !== "offline")

    // Signal from 0 to 1, whatever scale the backend uses.
    function strength(network: var): real {
        const value = network?.signalStrength ?? 0;
        return value > 1 ? value / 100 : value;
    }
    function signalIcon(value: real): string {
        return value > 0.66 ? "wifi.svg" : value > 0.4 ? "wifi-2.svg" : value > 0.15 ? "wifi-1.svg" : "wifi-0.svg";
    }
    readonly property string iconName: wired ? "ethernet.svg"
        : activeWifi ? signalIcon(strength(activeWifi))
        : "wifi-off.svg"
    readonly property string title: wired ? "Cabo" : activeWifi ? activeWifi.name : "Sem conexão"
    readonly property string detail: {
        if (kind === "offline") return wifi ? "Escolha uma rede Wi-Fi" : "Nenhuma rede disponível";
        const speed = wired && wired.linkSpeed > 0 ? (wired.linkSpeed >= 1000 ? wired.linkSpeed / 1000 + " Gb/s" : wired.linkSpeed + " Mb/s") : "";
        const reach = Networking.connectivity === NetworkConnectivity.Portal ? "Login necessário"
            : Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.None ? "Sem internet"
            : "Conectado";
        return [reach, speed, activeWifi ? Math.round(strength(activeWifi) * 100) + "% de sinal" : ""].filter(part => part).join(" · ");
    }
    function secured(network: var): bool {
        return network?.security !== WifiSecurityType.Open && network?.security !== WifiSecurityType.Unknown;
    }
    function failure(reason: int): string {
        return reason === ConnectionFailReason.NoSecrets ? "Senha incorreta ou ausente"
            : reason === ConnectionFailReason.WifiAuthTimeout ? "A rede não respondeu a tempo"
            : reason === ConnectionFailReason.WifiNetworkLost ? "A rede ficou fora de alcance"
            : "Não foi possível conectar";
    }
    function openSettings(): void { Quickshell.execDetached([Config.Settings.networkCommand]); }
}
