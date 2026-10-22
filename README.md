# TransWell

Transport commission agents ke liye Android app (Flutter): trips, party / truck owner ka hisaab, bilty, directory, load board, live tracking — aur truck owner, driver, shipper ke liye alag screens.

## Abhi kya hai (v0.2)

- **Login:** mobile number + 6 ank ka PIN (pehli baar jo PIN rakho wahi aage). SMS OTP tab judega jab SMS provider (MSG91 / Twilio) ki key milegi.
- **Backend:** Supabase project `TransWell` (Mumbai). Har table pe row-level security: agent ko sirf apne office ka data; truck owner, driver aur shipper apne **mobile number** se apne trips dekhte hain (agent ne directory mein jo number daala).
- **Agent:** office setup, party / owner / truck jodna, trip (LR apne aap), payment / kata, ledger, bilty + statement PDF share, WhatsApp reminder, load board, live map.
- **Driver (Hindi):** loaded / pahunch gaya, har 2 minute location (jab tak app khula hai), POD photo upload.
- **Truck owner:** apne trips aur hisaab, gaadi kahan hai, "gaadi khaali hai" post.
- **Shipper:** maal kahan hai (map + km bacha), POD, hisaab, load post.

Abhi baaki: background location (app band hone pe bhi), push notifications (Firebase project chahiye), SMS OTP, offline mode.

## APK kaise milta hai

`main` branch pe har push pe GitHub Actions APK banata hai aur **Releases** mein daal deta hai: https://github.com/spywellinfotech-sys/TransWell/releases/latest

Android project (`android/`) build ke waqt `flutter create` se banta hai, isliye repo mein sirf `lib/` aur `pubspec.yaml` hain; permissions `tool/patch_android.py` jodta hai.
