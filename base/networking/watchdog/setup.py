import setuptools

setuptools.setup(
    name="playos_network_watchdog",
    version="0.1.0",
    description="PlayOS Network Watchdog",
    py_modules=['watchdog'],
    packages=setuptools.find_packages(),
    entry_points={
        'console_scripts': ['playos-network-watchdog = watchdog:main' ]
    }
)
