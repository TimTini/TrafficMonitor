#pragma once

#include <array>
#include <chrono>
#include <mutex>
#include <string>

class CPriceDataManager
{
public:
    static constexpr int MAX_ITEM_COUNT = 8;

    static CPriceDataManager& Instance();

    void LoadConfig(const std::wstring& config_dir);
    void SaveConfig() const;
    void FetchPricesIfNeeded();

    int GetItemCount() const;
    const wchar_t* GetItemName(int item_index) const;
    const wchar_t* GetItemId(int item_index) const;
    const wchar_t* GetItemLabel(int item_index) const;
    const wchar_t* GetItemSampleText(int item_index) const;
    const wchar_t* GetItemValueText(int item_index) const;
    const wchar_t* GetTooltipInfo() const;
    std::wstring GetConfigPath() const;
    bool IsDefaultTaskbarItem(int item_index) const;

private:
    struct PriceAsset
    {
        std::wstring name;
        std::wstring item_id;
        std::wstring label;
        std::wstring inst_id;
        std::wstring sample_text;
        std::wstring value_text;
    };

    CPriceDataManager();

    bool IsValidIndex(int item_index) const;

    std::wstring BuildDefaultConfigPath() const;
    std::wstring ReadIniString(const wchar_t* section, const wchar_t* key, const std::wstring& default_value) const;
    int ReadIniInt(const wchar_t* section, const wchar_t* key, int default_value) const;
    void UpdateItemNameAndSample(PriceAsset& asset) const;
    std::wstring MakeIndexedKey(const wchar_t* key_prefix, int item_index) const;

    std::string DownloadOkxTickers(const std::wstring& api_host) const;
    std::string ExtractLastPrice(const std::string& json_text, const std::wstring& inst_id) const;
    std::wstring FormatPriceText(const std::string& price_text, int decimal_places) const;
    std::string WideToUtf8(const std::wstring& text) const;

private:
    mutable std::mutex m_data_mutex;
    std::array<PriceAsset, MAX_ITEM_COUNT> m_assets;
    std::wstring m_api_host{ L"www.okx.com" };
    std::wstring m_config_path;
    std::wstring m_last_error;
    int m_update_interval_ms{ 1000 };
    int m_item_count{ 3 };
    int m_decimal_places{ 1 };
    std::chrono::steady_clock::time_point m_last_fetch_time{};
};
