#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>

#include "PriceDataManager.h"

#include <algorithm>
#include <cstdlib>
#include <cwchar>
#include <vector>

extern "C" IMAGE_DOS_HEADER __ImageBase;

namespace
{
    constexpr int MIN_UPDATE_INTERVAL_MS = 1000;
    constexpr DWORD OKX_CONNECT_TIMEOUT_MS = 1000;
    constexpr DWORD OKX_SEND_TIMEOUT_MS = 1000;
    constexpr DWORD OKX_RECEIVE_TIMEOUT_MS = 2000;
    constexpr size_t MAX_RESPONSE_SIZE = 2 * 1024 * 1024;

    std::wstring AppendFileName(const std::wstring& dir, const wchar_t* file_name)
    {
        if (dir.empty())
            return file_name;

        wchar_t last_char = dir.back();
        if (last_char == L'\\' || last_char == L'/')
            return dir + file_name;

        return dir + L"\\" + file_name;
    }

    bool IsBlank(const std::wstring& text)
    {
        return std::all_of(text.begin(), text.end(), [](wchar_t ch) {
            return iswspace(ch) != 0;
        });
    }
}

CPriceDataManager::CPriceDataManager()
    : m_assets{
        PriceAsset{
            L"OKX BTC price",
            L"okx_price_btc_usdt",
            L"BTC:",
            L"btc_inst_id",
            L"BTC-USDT",
            L"$88888",
            L"--"
        },
        PriceAsset{
            L"OKX ETH price",
            L"okx_price_eth_usdt",
            L"ETH:",
            L"eth_inst_id",
            L"ETH-USDT",
            L"$8888.8",
            L"--"
        },
        PriceAsset{
            L"OKX XAU price",
            L"okx_price_xau_proxy",
            L"XAU:",
            L"xau_inst_id",
            L"XAUT-USDT",
            L"$8888.8",
            L"--"
        }
    }
{
}

CPriceDataManager& CPriceDataManager::Instance()
{
    static CPriceDataManager instance;
    return instance;
}

void CPriceDataManager::LoadConfig(const std::wstring& config_dir)
{
    std::lock_guard<std::mutex> lock(m_data_mutex);

    m_config_path = config_dir.empty()
        ? BuildDefaultConfigPath()
        : AppendFileName(config_dir, L"PricePlugin.ini");

    m_api_host = ReadIniString(L"config", L"api_host", m_api_host);
    if (IsBlank(m_api_host))
        m_api_host = L"www.okx.com";

    m_update_interval_ms = ReadIniInt(L"config", L"update_interval_ms", MIN_UPDATE_INTERVAL_MS);
    if (m_update_interval_ms < MIN_UPDATE_INTERVAL_MS)
        m_update_interval_ms = MIN_UPDATE_INTERVAL_MS;

    for (auto& asset : m_assets)
    {
        std::wstring inst_id = ReadIniString(L"market", asset.config_key.c_str(), asset.inst_id);
        if (!IsBlank(inst_id))
            asset.inst_id = inst_id;
    }

    SaveConfig();
}

void CPriceDataManager::FetchPricesIfNeeded()
{
    std::array<std::wstring, ITEM_COUNT> inst_ids;
    std::wstring api_host;

    auto now = std::chrono::steady_clock::now();
    {
        std::lock_guard<std::mutex> lock(m_data_mutex);
        auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - m_last_fetch_time).count();
        if (m_last_fetch_time.time_since_epoch().count() != 0 && elapsed_ms < m_update_interval_ms)
            return;

        m_last_fetch_time = now;
        api_host = m_api_host;
        for (size_t index = 0; index < m_assets.size(); ++index)
            inst_ids[index] = m_assets[index].inst_id;
    }

    std::string json_text = DownloadOkxTickers(api_host);
    if (json_text.empty())
    {
        std::lock_guard<std::mutex> lock(m_data_mutex);
        m_last_error = L"OKX request failed";
        return;
    }

    std::array<std::wstring, ITEM_COUNT> new_values;
    std::array<bool, ITEM_COUNT> has_value{};
    for (size_t index = 0; index < inst_ids.size(); ++index)
    {
        std::string price_text = ExtractLastPrice(json_text, inst_ids[index]);
        if (!price_text.empty())
        {
            new_values[index] = FormatPriceText(price_text);
            has_value[index] = true;
        }
    }

    std::lock_guard<std::mutex> lock(m_data_mutex);
    bool updated_any = false;
    for (size_t index = 0; index < m_assets.size(); ++index)
    {
        if (has_value[index])
        {
            m_assets[index].value_text = new_values[index];
            updated_any = true;
        }
    }

    m_last_error = updated_any ? L"" : L"OKX instruments not found";
}

const wchar_t* CPriceDataManager::GetItemName(int item_index) const
{
    if (!IsValidIndex(item_index))
        return L"OKX price";

    return m_assets[item_index].name.c_str();
}

const wchar_t* CPriceDataManager::GetItemId(int item_index) const
{
    if (!IsValidIndex(item_index))
        return L"okx_price_unknown";

    return m_assets[item_index].item_id.c_str();
}

const wchar_t* CPriceDataManager::GetItemLabel(int item_index) const
{
    if (!IsValidIndex(item_index))
        return L"OKX:";

    return m_assets[item_index].label.c_str();
}

const wchar_t* CPriceDataManager::GetItemSampleText(int item_index) const
{
    if (!IsValidIndex(item_index))
        return L"$88888";

    return m_assets[item_index].sample_text.c_str();
}

const wchar_t* CPriceDataManager::GetItemValueText(int item_index) const
{
    thread_local std::wstring value_text;

    std::lock_guard<std::mutex> lock(m_data_mutex);
    if (!IsValidIndex(item_index))
    {
        value_text = L"--";
    }
    else
    {
        value_text = m_assets[item_index].value_text;
    }

    return value_text.c_str();
}

const wchar_t* CPriceDataManager::GetTooltipInfo() const
{
    thread_local std::wstring tooltip_text;

    std::lock_guard<std::mutex> lock(m_data_mutex);
    tooltip_text = L"OKX prices";
    for (const auto& asset : m_assets)
    {
        tooltip_text += L"\r\n";
        tooltip_text += asset.label;
        tooltip_text += L" ";
        tooltip_text += asset.value_text;
        tooltip_text += L" (";
        tooltip_text += asset.inst_id;
        tooltip_text += L")";
    }

    if (!m_last_error.empty())
    {
        tooltip_text += L"\r\n";
        tooltip_text += m_last_error;
    }

    return tooltip_text.c_str();
}

bool CPriceDataManager::IsValidIndex(int item_index) const
{
    return item_index >= 0 && item_index < ITEM_COUNT;
}

void CPriceDataManager::SaveConfig() const
{
    if (m_config_path.empty())
        return;

    WritePrivateProfileStringW(L"config", L"api_host", m_api_host.c_str(), m_config_path.c_str());
    std::wstring interval_text = std::to_wstring(m_update_interval_ms);
    WritePrivateProfileStringW(L"config", L"update_interval_ms", interval_text.c_str(), m_config_path.c_str());

    for (const auto& asset : m_assets)
        WritePrivateProfileStringW(L"market", asset.config_key.c_str(), asset.inst_id.c_str(), m_config_path.c_str());
}

std::wstring CPriceDataManager::BuildDefaultConfigPath() const
{
    wchar_t path[MAX_PATH]{};
    GetModuleFileNameW(reinterpret_cast<HMODULE>(&__ImageBase), path, MAX_PATH);
    return std::wstring(path) + L".ini";
}

std::wstring CPriceDataManager::ReadIniString(const wchar_t* section, const wchar_t* key, const std::wstring& default_value) const
{
    wchar_t buffer[256]{};
    GetPrivateProfileStringW(section, key, default_value.c_str(), buffer, static_cast<DWORD>(std::size(buffer)), m_config_path.c_str());
    return buffer;
}

int CPriceDataManager::ReadIniInt(const wchar_t* section, const wchar_t* key, int default_value) const
{
    return GetPrivateProfileIntW(section, key, default_value, m_config_path.c_str());
}

std::string CPriceDataManager::DownloadOkxTickers(const std::wstring& api_host) const
{
    HINTERNET session = WinHttpOpen(
        L"TrafficMonitor PricePlugin/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS,
        0);
    if (session == nullptr)
        return {};

    HINTERNET connect = nullptr;
    HINTERNET request = nullptr;
    auto close_handles = [&]() {
        if (request != nullptr)
            WinHttpCloseHandle(request);
        if (connect != nullptr)
            WinHttpCloseHandle(connect);
        if (session != nullptr)
            WinHttpCloseHandle(session);
    };

    WinHttpSetTimeouts(
        session,
        OKX_CONNECT_TIMEOUT_MS,
        OKX_SEND_TIMEOUT_MS,
        OKX_RECEIVE_TIMEOUT_MS,
        OKX_RECEIVE_TIMEOUT_MS);

    connect = WinHttpConnect(session, api_host.c_str(), INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (connect == nullptr)
    {
        close_handles();
        return {};
    }

    request = WinHttpOpenRequest(
        connect,
        L"GET",
        L"/api/v5/market/tickers?instType=SPOT",
        nullptr,
        WINHTTP_NO_REFERER,
        WINHTTP_DEFAULT_ACCEPT_TYPES,
        WINHTTP_FLAG_SECURE);
    if (request == nullptr)
    {
        close_handles();
        return {};
    }

    WinHttpAddRequestHeaders(
        request,
        L"Accept: application/json\r\n",
        static_cast<DWORD>(-1),
        WINHTTP_ADDREQ_FLAG_ADD);

    BOOL ok = WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0);
    if (ok)
        ok = WinHttpReceiveResponse(request, nullptr);

    if (!ok)
    {
        close_handles();
        return {};
    }

    DWORD status_code = 0;
    DWORD status_code_size = sizeof(status_code);
    ok = WinHttpQueryHeaders(
        request,
        WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
        WINHTTP_HEADER_NAME_BY_INDEX,
        &status_code,
        &status_code_size,
        WINHTTP_NO_HEADER_INDEX);
    if (!ok || status_code != 200)
    {
        close_handles();
        return {};
    }

    std::string response_text;
    while (true)
    {
        DWORD bytes_available = 0;
        if (!WinHttpQueryDataAvailable(request, &bytes_available))
        {
            close_handles();
            return {};
        }

        if (bytes_available == 0)
            break;

        if (response_text.size() + bytes_available > MAX_RESPONSE_SIZE)
        {
            close_handles();
            return {};
        }

        std::vector<char> buffer(bytes_available);
        DWORD bytes_read = 0;
        if (!WinHttpReadData(request, buffer.data(), bytes_available, &bytes_read))
        {
            close_handles();
            return {};
        }

        response_text.append(buffer.data(), bytes_read);
    }

    close_handles();
    return response_text;
}

std::string CPriceDataManager::ExtractLastPrice(const std::string& json_text, const std::wstring& inst_id) const
{
    std::string inst_id_utf8 = WideToUtf8(inst_id);
    std::string inst_marker = "\"instId\":\"" + inst_id_utf8 + "\"";

    size_t inst_pos = json_text.find(inst_marker);
    if (inst_pos == std::string::npos)
        return {};

    size_t object_end = json_text.find('}', inst_pos);
    if (object_end == std::string::npos)
        return {};

    const std::string last_marker = "\"last\":\"";
    size_t last_pos = json_text.find(last_marker, inst_pos);
    if (last_pos == std::string::npos || last_pos > object_end)
        return {};

    size_t value_start = last_pos + last_marker.size();
    size_t value_end = json_text.find('"', value_start);
    if (value_end == std::string::npos || value_end > object_end)
        return {};

    return json_text.substr(value_start, value_end - value_start);
}

std::wstring CPriceDataManager::FormatPriceText(const std::string& price_text) const
{
    char* end_ptr = nullptr;
    double price = std::strtod(price_text.c_str(), &end_ptr);
    if (end_ptr == price_text.c_str() || price <= 0)
        return L"--";

    wchar_t buffer[64]{};
    if (price >= 10000)
        swprintf_s(buffer, L"$%.0f", price);
    else if (price >= 1000)
        swprintf_s(buffer, L"$%.1f", price);
    else if (price >= 1)
        swprintf_s(buffer, L"$%.2f", price);
    else
        swprintf_s(buffer, L"$%.6f", price);

    return buffer;
}

std::string CPriceDataManager::WideToUtf8(const std::wstring& text) const
{
    if (text.empty())
        return {};

    int source_size = static_cast<int>(text.size());
    int size = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), source_size, nullptr, 0, nullptr, nullptr);
    if (size <= 0)
        return {};

    std::string result(static_cast<size_t>(size), '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.c_str(), source_size, result.data(), size, nullptr, nullptr);
    return result;
}
