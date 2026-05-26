# OKX Price Plugin

TrafficMonitor plugin hiển thị 3 giá lấy từ OKX mỗi 1 giây:

- `BTC:` mặc định dùng `BTC-USDT`
- `ETH:` mặc định dùng `ETH-USDT`
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

[market]
btc_inst_id=BTC-USDT
eth_inst_id=ETH-USDT
xau_inst_id=XAUT-USDT
```

Nếu muốn dùng token vàng khác trên OKX, đổi `xau_inst_id`, ví dụ `PAXG-USDT`.
