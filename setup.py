#!/usr/bin/env python

"""The setup script."""

from setuptools import Extension, find_packages, setup  # NOQA
from Cython.Build import cythonize

with open('README.rst') as readme_file:
    readme = readme_file.read()

with open('HISTORY.rst') as history_file:
    history = history_file.read()

requirements = ['Click>=7.0', ]

setup_requirements = [ ]

test_requirements = [ ]

setup(
    author="Matthew Turk",
    author_email='matthewturk@gmail.com',
    python_requires='>=3.5',
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: GNU General Public License v3 (GPLv3)',
        'Natural Language :: English',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
    ],
    description="Wrapper around libdvdnav",
    entry_points={
        'console_scripts': [
            'pydvdnav=pydvdnav.cli:main',
        ],
    },
    install_requires=requirements,
    license="GNU General Public License v3",
    long_description=readme + '\n\n' + history,
    include_package_data=True,
    keywords='pydvdnav',
    name='pydvdnav',
    packages=find_packages(include=['pydvdnav', 'pydvdnav.*']),
    setup_requires=setup_requirements,
    test_suite='tests',
    tests_require=test_requirements,
    url='https://github.com/matthewturk/pydvdnav',
    version='0.1.0',
    zip_safe=False,
    ext_modules=cythonize("pydvdnav/*.pyx"),
    include_dirs=[],
)
