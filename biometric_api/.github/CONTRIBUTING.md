# Contributing to Biometric API Microservice 🧬

Thank you for your interest in contributing to the **Biometric API Microservice**! We welcome contributions from developers of all skill levels.

---

## 📜 Code of Conduct

Please treat all community members with respect and professionalism. Maintain constructive feedback and inclusive communication.

---

## 🛠️ Development Setup

1. **Fork & Clone Repository:**
   ```bash
   git clone https://github.com/ankurrera/Biometric-API.git
   cd Biometric-API
   ```

2. **Set up Virtual Environment:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt pytest
   ```

3. **Run Unit Tests:**
   ```bash
   python3 -m pytest test_biometric_pipeline.py -v
   ```

---

## 🚀 Pull Request Workflow

1. Create a feature branch: `git checkout -b feat/your-feature-name`.
2. Ensure all 13 unit tests pass: `python3 -m pytest test_biometric_pipeline.py -v`.
3. Format commit messages using semantic tags: `feat(scope): short description` or `fix(scope): short description`.
4. Submit a Pull Request targeting `main`.

---

## 🧪 Benchmark Guidelines

If your PR modifies facial embedding extraction, alignment, or database search logic, run `python3 benchmark_suite.py` and attach the latency output to your Pull Request.
