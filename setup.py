from setuptools import setup, find_packages

setup(
    name="convcommitgpt",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "click==8.1.7",
        "openai>=1.12.0",
        "gitpython==3.1.43",
        "python-dotenv==1.0.1",
    ],
    extras_require={
        "dev": [
            "pytest==8.0.0",
            "pytest-cov==4.1.0",
            "pytest-mock==3.12.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "convcommit=convcommit:main",
        ],
    },
) 