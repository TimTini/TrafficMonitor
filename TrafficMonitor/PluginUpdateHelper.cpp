#include "stdafx.h"
#include "PluginUpdateHelper.h"
#include "Common.h"
#include "TrafficMonitor.h"
#include "TinyXml2Helper.h"

static void VersionFromString(const std::string& version_str, std::vector<int>& versions)
{
    versions.clear();
    //拆分字符串
    std::vector<std::string> vec_version;
    CCommon::StringSplit(version_str, '.', vec_version);
    //转换为整数保存
    for (const auto& str : vec_version)
    {
        //去掉除数字以外的字符
        std::string str_ver;
        for (auto ch : str)
        {
            if (ch >= '0' && ch <= '9')
                str_ver.push_back(ch);
        }

        versions.push_back(atoi(str_ver.c_str()));
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
PluginVersion::PluginVersion()
{
}

PluginVersion::PluginVersion(const std::wstring& version)
{
    m_version_str = CCommon::AsciiToStr(version);
    VersionFromString(m_version_str, m_version);
}

PluginVersion::PluginVersion(const std::string& version)
{
    m_version_str = version;
    VersionFromString(m_version_str, m_version);
}

bool PluginVersion::operator<(const PluginVersion& another) const
{
    for (size_t i{}; i < m_version.size() || i < another.m_version.size(); i++)
    {
        if (GetSubVersion(i) < another.GetSubVersion(i))
            return true;
    }
    return false;
}

bool PluginVersion::operator==(const PluginVersion& another) const
{
    for (size_t i{}; i < m_version.size() || i < another.m_version.size(); i++)
    {
        if (GetSubVersion(i) != another.GetSubVersion(i))
            return false;
    }
    return true;
}

std::string PluginVersion::GetVersionString() const
{
    return m_version_str;
}

std::wstring PluginVersion::GetVersionWString() const
{
    return CCommon::AsciiToUnicode(m_version_str);
}

int PluginVersion::GetSubVersion(size_t index) const
{
    if (index < m_version.size())
        return m_version[index];
    return 0;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
bool CPluginUpdateHelper::CheckForUpdate()
{
    m_latest_versions.clear();
    UNREFERENCED_PARAMETER(theApp);
    return true;
}

const PluginVersion& CPluginUpdateHelper::GetPluginLatestVersions(const std::wstring& file_name) const
{
    auto iter = m_latest_versions.find(file_name);
    if (iter != m_latest_versions.end())
    {
        return iter->second;
    }
    static PluginVersion empty_version;
    return empty_version;
}
