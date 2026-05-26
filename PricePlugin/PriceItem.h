#pragma once

#include "PluginInterface.h"

class CPriceItem : public IPluginItem
{
public:
    explicit CPriceItem(int item_index);

    const wchar_t* GetItemName() const override;
    const wchar_t* GetItemId() const override;
    const wchar_t* GetItemLableText() const override;
    const wchar_t* GetItemValueText() const override;
    const wchar_t* GetItemValueSampleText() const override;

private:
    int m_item_index{};
};
