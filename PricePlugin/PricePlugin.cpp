#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>

#include "PricePlugin.h"

#include "PriceDataManager.h"

CPricePlugin::CPricePlugin()
    : m_items{
        CPriceItem(0), CPriceItem(1), CPriceItem(2), CPriceItem(3),
        CPriceItem(4), CPriceItem(5), CPriceItem(6), CPriceItem(7)
    }
{
    CPriceDataManager::Instance().LoadConfig(L"");
}

CPricePlugin& CPricePlugin::Instance()
{
    static CPricePlugin instance;
    return instance;
}

IPluginItem* CPricePlugin::GetItem(int index)
{
    if (index < 0 || index >= CPriceDataManager::Instance().GetItemCount())
        return nullptr;

    return &m_items[index];
}

void CPricePlugin::DataRequired()
{
    CPriceDataManager::Instance().FetchPricesIfNeeded();
}

const wchar_t* CPricePlugin::GetInfo(PluginInfoIndex index)
{
    switch (index)
    {
    case TMI_NAME:
        return L"OKX Price";
    case TMI_DESCRIPTION:
        return L"Shows custom OKX spot prices every 1 second.";
    case TMI_AUTHOR:
        return L"TrafficMonitor local plugin";
    case TMI_COPYRIGHT:
        return L"Local use";
    case TMI_VERSION:
        return L"1.0";
    case TMI_URL:
        return L"https://www.okx.com/docs-v5/en/";
    default:
        return L"";
    }
}

ITMPlugin::OptionReturn CPricePlugin::ShowOptionsDialog(void* hParent)
{
    HWND parent_wnd = reinterpret_cast<HWND>(hParent);
    CPriceDataManager::Instance().SaveConfig();
    std::wstring config_path = CPriceDataManager::Instance().GetConfigPath();
    std::wstring message = L"PricePlugin.ini will open in Notepad.\r\n\r\n"
        L"Edit item_count, decimal_places, and item*_inst_id/item*_label, then restart TrafficMonitor to add/remove price slots.";
    MessageBoxW(parent_wnd, message.c_str(), L"OKX Price settings", MB_OK | MB_ICONINFORMATION);

    std::wstring quoted_path = L"\"" + config_path + L"\"";
    ShellExecuteW(parent_wnd, L"open", L"notepad.exe", quoted_path.c_str(), nullptr, SW_SHOWNORMAL);
    return ITMPlugin::OR_OPTION_UNCHANGED;
}

void CPricePlugin::OnExtenedInfo(ExtendedInfoIndex index, const wchar_t* data)
{
    if (index == ITMPlugin::EI_CONFIG_DIR && data != nullptr)
        CPriceDataManager::Instance().LoadConfig(data);
}

const wchar_t* CPricePlugin::GetTooltipInfo()
{
    return CPriceDataManager::Instance().GetTooltipInfo();
}

ITMPlugin* TMPluginGetInstance()
{
    return &CPricePlugin::Instance();
}
