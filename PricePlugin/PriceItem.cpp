#include "PriceItem.h"

#include "PriceDataManager.h"

CPriceItem::CPriceItem(int item_index)
    : m_item_index(item_index)
{
}

const wchar_t* CPriceItem::GetItemName() const
{
    return CPriceDataManager::Instance().GetItemName(m_item_index);
}

const wchar_t* CPriceItem::GetItemId() const
{
    return CPriceDataManager::Instance().GetItemId(m_item_index);
}

const wchar_t* CPriceItem::GetItemLableText() const
{
    return CPriceDataManager::Instance().GetItemLabel(m_item_index);
}

const wchar_t* CPriceItem::GetItemValueText() const
{
    return CPriceDataManager::Instance().GetItemValueText(m_item_index);
}

const wchar_t* CPriceItem::GetItemValueSampleText() const
{
    return CPriceDataManager::Instance().GetItemSampleText(m_item_index);
}

void* CPriceItem::OnItemInfo(ItemInfoType type, void* para1, void* para2)
{
    (void)para1;
    (void)para2;

    if (type == IIT_DEFAULT_TASKBAR_DISPLAY && CPriceDataManager::Instance().IsDefaultTaskbarItem(m_item_index))
        return reinterpret_cast<void*>(1);

    return nullptr;
}
