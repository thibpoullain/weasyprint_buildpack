# WeasyPrint Buildpack for Scalingo

[![Scalingo](https://img.shields.io/badge/Scalingo-Compatible-blue.svg)](https://scalingo.com)
[![WeasyPrint](https://img.shields.io/badge/WeasyPrint-65.1-green.svg)](https://weasyprint.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Custom buildpack to install **WeasyPrint** and all its system dependencies on Scalingo. WeasyPrint is a Python library that generates PDF documents from HTML and CSS.

## 🚀 Quick Start

### Option 1: Use this buildpack directly

```bash
scalingo env-set BUILDPACK_URL=https://github.com/thibpoullain/weasyprint_buildpack
```

### Option 2: Multi-buildpack (recommended)

Create a `.buildpacks` file at the root of your project:

```
https://github.com/thibpoullain/weasyprint_buildpack
https://github.com/Scalingo/python-buildpack
```

## 📋 Prerequisites

- Python application with WeasyPrint in dependencies
- Scalingo Stack: `scalingo-22` (Ubuntu 22.04)

## 🔧 Installation

1. **Add WeasyPrint to your Python dependencies**:

   ```bash
   # requirements.txt
   WeasyPrint>=65.0
   ```

2. **Configure the buildpack**:

   ```bash
   scalingo env-set BUILDPACK_URL=https://github.com/thibpoullain/weasyprint_buildpack
   ```

3. **Deploy your application**:

   ```bash
   git push scalingo main
   ```

## 📦 What this buildpack does

### System dependencies installed

- **Build tools**: `build-essential`, `pkg-config`
- **Python**: `python3-dev`, `python3-pip`
- **Cairo**: `libcairo2`, `libcairo2-dev`
- **Pango**: `libpango-1.0-0`, `libpangocairo-1.0-0`
- **Images**: `libgdk-pixbuf2.0-0`, `libjpeg-dev`, `libopenjp2-7-dev`
- **Text**: `libharfbuzz0b`, `libharfbuzz-dev`
- **Others**: `libffi-dev`, `shared-mime-info`

### Automatic configuration

- Environment variables for library paths
- PKG_CONFIG_PATH configuration
- Font support via FONTCONFIG_PATH
- APT package cache between builds

## 💻 Usage Example

```python
from flask import Flask, make_response
import weasyprint

app = Flask(__name__)

@app.route('/generate-pdf')
def generate_pdf():
    html = '''
    <html>
        <head>
            <style>
                body { font-family: Arial; margin: 40px; }
                h1 { color: #2c3e50; }
            </style>
        </head>
        <body>
            <h1>PDF Document Generated with WeasyPrint</h1>
            <p>This is an example of PDF generation on Scalingo.</p>
        </body>
    </html>
    '''

    pdf = weasyprint.HTML(string=html).write_pdf()
    response = make_response(pdf)
    response.headers['Content-Type'] = 'application/pdf'
    response.headers['Content-Disposition'] = 'attachment; filename=document.pdf'

    return response

if __name__ == '__main__':
    app.run()
```

## 🧪 Local Testing

To test the buildpack locally with Docker:

```bash
# Build the test image
make build-runtime

# Run the tests
make test-runtime
```

## 🏗️ Buildpack Structure

```
weasyprint-buildpack/
├── bin/
│   ├── compile      # Main installation script
│   ├── detect       # Detects if app uses WeasyPrint
│   └── release      # Configures runtime environment
├── docker/
│   └── scalingo-runtime/
│       ├── Dockerfile    # Scalingo test image
│       └── test.sh       # Automated test script
├── LICENSE
├── Makefile
└── README.md
```

## 🔍 Troubleshooting

### Issue: "cannot import name 'ffi' from 'cairocffi'"

**Solution**: The buildpack automatically installs `cffi` and `cairocffi`. If the problem persists, check your versions:

```python
# requirements.txt
cffi>=1.15.0
cairocffi>=1.3.0
WeasyPrint>=65.0
```

### Issue: "Package cairo was not found in the pkg-config search path"

**Solution**: Environment variables are automatically configured. If you encounter this issue locally, export:

```bash
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH
```

### Issue: Missing fonts

**Solution**: Add your custom fonts in a `fonts/` folder and configure:

```python
from weasyprint import HTML, CSS
from weasyprint.text.fonts import FontConfiguration

font_config = FontConfiguration()
html = HTML(string=html_string)
css = CSS(string='@font-face { font-family: "Custom"; src: url("fonts/custom.ttf"); }',
          font_config=font_config)
html.write_pdf(stylesheets=[css], font_config=font_config)
```

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork the project
2. Create your feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add feature'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Create a Pull Request

## 📝 Changelog

### v1.0.0 (2025-01-19)
- Initial support for WeasyPrint 65.x
- Automatic installation of system dependencies
- Cairo/Pango environment configuration
- Cache system to speed up builds
- Automated tests with Docker

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/thibpoullain/weasyprint_buildpack/issues)
- **WeasyPrint Documentation**: [weasyprint.org](https://weasyprint.org/)
- **Scalingo Documentation**: [doc.scalingo.com](https://doc.scalingo.com/)

---

Made with ❤️ for the Scalingo community
