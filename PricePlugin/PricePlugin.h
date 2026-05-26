#pragma once

#include <array>

#include "PluginInterface.h"
#include "PriceDataManager.h"
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
    std::array<CPriceItem, CPriceDataManager::MAX_ITEM_COUNT> m_items;
};

extern "C" __declspec(dllexport) ITMPlugin* TMPluginGetInstance();
