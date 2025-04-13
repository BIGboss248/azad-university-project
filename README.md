# پروژه کارشناسی دانشگاه آزاد

این پروژه با هدف ساده سازی روند اجرای سایت وردپرس روی یک سرور مجازی ایجاد شده در ادامه نحوه استفاده از فایل های این مخزن برای اجرای سایت وردپرس و بهینه سازی آن میپردازیم

## نحوه اچرای پروژه

کافی است فقط فرمان زیر را اجرا کنید و توکن کلودفلر و نام دامنه خود را وارد کنید

```console
sudo rm -rf azad-university-project .cloudflare setup.bash
curl -O https://raw.githubusercontent.com/BIGboss248/azad-university-project/refs/heads/main/setup.bash
chmod +x setup.bash
./setup.bash
```

اگر دامنه یا توکن را در اختیار ندارید برای راهنمایی فایل pdf را مطالعه کنید
