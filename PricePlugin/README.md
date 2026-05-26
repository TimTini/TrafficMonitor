# OKX Price Plugin

TrafficMonitor plugin hiển thị giá lấy từ OKX mỗi 1 giây:

- Mặc định có 3 slot: `BTC-USDT`, `ETH-USDT`, `XAUT-USDT`
- Có thể tăng `item_count` tối đa 8 slot và đổi `item*_inst_id`
- Giá mặc định hiển thị 1 chữ số thập phân (`decimal_places=1`)
- `XAU:` mặc định dùng `XAUT-USDT` vì OKX không có mã spot `XAU-USDT`

Build mặc định:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_price_plugin.ps1 -Configuration Release -Platform x64
```

DLL sau build nằm ở:

```text
Bin\x64\Release\plugins\PricePlugin.dll
```

Sau khi chạy TrafficMonitor lần đầu, plugin tạo file cấu hình `PricePlugin.ini` trong thư mục cấu hình plugin. Có thể sửa:

```ini
[config]
api_host=www.okx.com
update_interval_ms=1000
decimal_places=1
item_count=3

[market]
item1_label=BTC:
item1_inst_id=BTC-USDT
item2_label=ETH:
item2_inst_id=ETH-USDT
item3_label=XAU:
item3_inst_id=XAUT-USDT
```

Nếu muốn dùng token vàng khác trên OKX, đổi `item3_inst_id`, ví dụ `PAXG-USDT`.

Bật hiển thị mặc định trên taskbar cho bản build local:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\enable_price_plugin_taskbar.ps1 -Configuration Release -Platform x64
```
