# cit-uploader

A command line interface to convert a CSV to a list of Custom Insert Terms and push them to the backend.
This is only a stopgap until the UI (phase 2) is finished.

## QA vs Production

To flip from QA to Production, toggle the USE_QA constant

## Cookies

No getting around it, you have to manually upload your vglnk.Agent.p/.q cookies if you want to pass validation. 
Good news is all you have to change is the COOKIE_VALUE and QA_COOKIE_VALUE fields respectively.
This will have to be changed if you sign in/out. 

## Usage

```
ruby cli-uploader.rb  -> Uploads data.csv in same directory
ruby cli-uploader.rb <filename.csv>   -> uploads the given filename in same directory
```
