import setuptools

with open("Readme.md", "r") as fh:
    long_description = fh.read()

setuptools.setup(
    name="kiosk_browser",
    version="0.1.0",
    author="Fabian Hauser",
    author_email="fabian.hauser@hsr.ch",
    description="Kiosk Browser",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/dividat/playos/",
    packages=setuptools.find_packages(),
    scripts=['bin/kiosk-browser'],
    classifiers=[
        "Programming Language :: Python :: 3",
    ],
)

