#
#
#            Nimrod's Runtime Library
#        (c) Copyright 2011 Alex Mitchell (Amrykid)
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## :Author: Alex Mitchell
##
## Implements a simple way to load strings based on the user's locale name.
##
## .. code-block:: Nimrod
##    initLocale(LocaleManager, "LocaleData.cfg") #Loads a config file with the localized strings.
##    echo(LocaleManager.getKey("Hello")) #Prints the localized string for the user's locale.
##    echo(LocaleManager.getKeyLang("Hello","de")) #Prints the localized string in the specified locale.
##    echo(<$>"Hello")
##
##
## Example CFG file:
##
## .. code-block::
##    SectionLang = en
##    [Hello] ;SectionLang makes Section headers into keys that are in that language.
##    es = "Hola"
##    de = "Hallo"


import strutils, xmlparser, tables, xmltree, os, parsecfg, streams
 
 
# FUNCTIONS RELATED TO GETTING LOCALE NAME    
when defined(windows):
  from windows import GetUserDefaultLCID, GetLocaleInfoA, LCID, LOCALE_SISO639LANGNAME

  proc GetWinLocaleName(): string =
    var locale = GetUserDefaultLCID()
    var localeName :array[0..265, char]
    var localeNameSize = GetLocaleInfoA(locale, LOCALE_SISO639LANGNAME, localeName, 256)
    return $localeName
        
else:
    import parseutils
    #TODO for *nix. MUST be named GetLocale and return name of the language.
    #proc getenv*(name: cstring): cstring {.header: "stdlib.h", importc: "getenv".}
    proc GetLocaleFromEnv(): string =
        var LANG = os.getenv("LANG")
        if LANG == "":
            # Language not set.
            return "Unknown"
        else:
            discard parseutils.parseUntil(LANG, result, '_')
 
type
  TLocaleManager* = object #An object used for localization via xml/cfg.
      table: TTable[string, TTable[string,string]]
      sectionLang: string
            
proc GetLocaleName*(): string =
  ## Retrieves the user's locale/language as an ISO 639-1 code string.
  when defined(windows):
      return GetWinLocaleName()
  else:
      #TODO for *nix
      return GetLocaleFromEnv()

proc loadXmlLocaleData*(locale: var TLocaleManager, filename: string) =
  ## Initializes a TLocaleManager by loading it with localized strings from a XML file.
  
  locale.table = initTable[string, TTable[string, string]]()
  var localeNode = loadXml(filename)
  for n in localeNode.items:
    if n.tag == "string":
      var key = n.attr("key")
      var innertable: TTable[string, string] = initTable[string, string]()
      for trans in n.items:
        if trans.tag == "trans":
          var lang = trans.attr("lang")
          var value = trans.attr("value") #using an attribute because PXmlNode.Text is broken.
          innertable.add(lang, value)
          
      locale.table.add(key, innertable)

proc loadCfgLocaleData*(locale: var TLocaleManager, filename: string) =
  ## Initializes a TLocaleManager by loading it with localized strings from a CFG file.
  locale.table = initTable[string, TTable[string, string]]()
  
  var f = newFileStream(filename, fmRead)
  if f != nil:
    var p: TCfgParser
    open(p, f, filename)

    var key: string
    var innertable: TTable[string, string] = initTable[string, string]()
    while true:
      var e = next(p)

      case e.kind
      of cfgEof: 
        #echo("EOF!")
        break
      of cfgSectionStart:   ## a ``[section]`` has been parsed
        #echo("new section: " & e.section)
        if innertable.len() > 0:
            locale.table.add(key, innertable)

        key = e.section
        innertable = initTable[string, string]()
      of cfgKeyValuePair:
        if key == nil and e.key == "SectionLang":
          locale.sectionLang = e.value
          #echo("Section Language: " & e.value)
        else:
          #echo("key-value-pair: " & e.key & ": " & e.value)
          innertable.add(e.key, e.value)
      of cfgError:
        echo(e.msg)
      else:
        continue

    if not locale.table.hasKey(key):
        locale.table.add(key, innertable)
        
    close(p)
  else:
    raise newException(EInvalidKey, "Invalid .cfg")


    
proc getKeyLang*(locale: var TLocaleManager, key: string, lang: string): string =
  ## Gets the localized string in the specified locale.

  if lang == locale.sectionLang:
    return key
  
  return locale.table.mget(key)[lang]
    
proc getKey*(locale: var TLocaleManager, key: string): string =
  ## Gets the localized string for the user's locale.
  return getKeyLang(locale,key, GetLocaleName())

template `<$>`(str: string): string = LocaleManager.getKey(str)
 
var
   LocaleManager: TLocaleManager
   
 
 
    
# DEBUGING TEST    
when isMainModule:
    echo(GetLocaleName()) #Prints English
    loadCfgLocaleData(LocaleManager, "LocaleData.cfg")
    echo(LocaleManager.getKey("Hello"))
    echo(LocaleManager.getKeyLang("Hello","de"))
    echo(<$>("Hello"))
