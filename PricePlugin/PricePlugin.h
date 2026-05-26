#pragma once

#include "PluginInterface.h"
#include "PriceItem.h"

class CPricePlugin : public ITMPlugin
{
private:
    CPricePlugin();

public:
    static CPricePlugin& Instance();

    IPluginItem* GetItem(int index) override;
    void DataRequired() override;
    const wchar_t* GetInfo(PluginInfoIndex index) override;
    OptionReturn ShowOptionsDialog(void* hParent) override;
    void OnExtenedInfo(ExtendedInfoIndex index, const wchar_t* data) override;
    const wchar_t* GetTooltipInfo() override;

private:
    CPriceItem m_btc_item;
    CPriceItem m_eth_item;
    CPriceItem m_xau_item;
};

extern "C" __declspec(dllexport) ITMPlugin* TMPluginGetInstance();
