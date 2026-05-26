#include "PricePlugin.h"

#include "PriceDataManager.h"

CPricePlugin::CPricePlugin()
    : m_btc_item(0)
    , m_eth_item(1)
    , m_xau_item(2)
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
    switch (index)
    {
    case 0:
        return &m_btc_item;
    case 1:
        return &m_eth_item;
    case 2:
        return &m_xau_item;
    default:
        return nullptr;
    }
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
        return L"Shows BTC, ETH, and XAU proxy prices from OKX every 1 second.";
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
    (void)hParent;
    return ITMPlugin::OR_OPTION_NOT_PROVIDED;
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
