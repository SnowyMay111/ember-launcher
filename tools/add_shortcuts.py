with open('windows/preview.html', 'r', encoding='utf-8') as f:
    c = f.read()

target = "const tabs = ['Home', 'Instances', 'Social', 'Explore', 'Skins', 'Settings'];"
replacement = """const tabs = ['Home', 'Instances', 'Social', 'Explore', 'Skins', 'Settings'];
    window.addEventListener('keydown', (e) => {
      const map = { '1': 'Home', '2': 'Instances', '3': 'Social', '4': 'Explore', '5': 'Skins', '6': 'Settings' };
      if (map[e.key] && !['INPUT', 'SELECT', 'TEXTAREA'].includes(document.activeElement.tagName)) {
        switchTab(map[e.key]);
      }
    });"""

c = c.replace(target, replacement)
with open('windows/preview.html', 'w', encoding='utf-8') as f:
    f.write(c)
print("Added 1-6 keyboard shortcuts to windows/preview.html")
