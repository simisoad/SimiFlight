# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'SimiFlightDocumentation'
copyright = '2025, Simi'
author = 'Simi'
release = 'develop'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = []

templates_path = ['_templates']
exclude_patterns = []

# suppress unnecessary warnings
suppress_warnings = [
    'misc.highlighting_failure',
    'toc.not_readable',
    'toc.secnum',
    'rest.underline',  # Diese Zeile unterdrückt Unterstreichungswarnungen
]



# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "furo"#'alabaster'
html_static_path = ['_static']
