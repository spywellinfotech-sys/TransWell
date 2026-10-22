"""Adds the permissions and intent queries TransWell needs to the generated
Android manifest. Safe to run more than once."""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "android/app/src/main/AndroidManifest.xml"
xml = open(path, encoding="utf-8").read()

perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
]
for p in perms:
    if p not in xml:
        xml = xml.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)

queries = """
    <queries>
        <intent><action android:name="android.intent.action.DIAL" /><data android:scheme="tel" /></intent>
        <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="tel" /></intent>
        <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent>
        <intent><action android:name="android.intent.action.SEND" /><data android:mimeType="*/*" /></intent>
        <intent><action android:name="android.intent.action.PROCESS_TEXT" /><data android:mimeType="text/plain" /></intent>
    </queries>
"""
if 'android:scheme="tel"' not in xml:
    if "<queries>" in xml:
        xml = re.sub(r"<queries>.*?</queries>", queries.strip(), xml, count=1, flags=re.S)
    else:
        xml = xml.replace("</manifest>", queries + "</manifest>", 1)

xml = re.sub(r'android:label="[^"]*"', 'android:label="TransWell"', xml, count=1)
open(path, "w", encoding="utf-8").write(xml)
print("patched", path)
