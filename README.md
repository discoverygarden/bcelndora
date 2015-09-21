# BCELNDORA

## Introduction

Customization module for British Columbia Electronic Libraries Network that contains custom form builder forms and form associations.

## Requirements

This module requires the following modules/libraries:

* [Islandora](https://github.com/islandora/islandora)
* [XML Form Builder](https://github.com/islandora/islandora_xml_forms)

## Installation

Install as usual, see [this](https://drupal.org/documentation/install/modules-themes/modules-7) for further information.

### Form Modifications

The form builder forms in this module can be customized by following the following steps: 

1. Through the admin UI clone the form you wish to change.

2. Modify the cloned form.

3. Test modifications.

4. Once the form has been confirmed to be working export the modified form.

5. In this repo go into the /xml folder and replace the the contents of the xml to the one you exported. 

Example Clone:

BC ELN Audio Form make changes and take the generated xml file.  Open /xml/bceln_audio_form.xml and replace the file contents with that of the exported file.

6. Commit the changes back to the git repository. 

7. Reinstall the module and all the forms that were modified will be updated.

## Troubleshooting/Issues

Having problems or solved a problem? Contact [discoverygarden](http://support.discoverygarden.ca).

## License

[GPLv3](http://www.gnu.org/licenses/gpl-3.0.txt)
