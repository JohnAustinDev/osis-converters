
# -*- coding: utf-8 -*-

import codecs, re

class ConversionConfig:
    
    def __init__(self, configFilePath):
        #
        # Set default to Russian book names
        self.books = {'Gen' : u'Бытие', 'Exod' : u'Исход', 'Lev' : u'Левит', 'Num' : u'Числа', 'Deut' : u'Второзаконие', \
                      'Josh' : u'Иисус Навин', 'Judg' : u'Книга Судей', 'Ruth' : u'Руфь', '1Sam' : u'1-я Царств', '2Sam' : u'2-я Царств', \
                      '1Kgs' : u'3-я Царств', '2Kgs' : u'4-я Царств', '1Chr' : u'1-я Паралипоменон', '2Chr' : u'2-я Паралипоменон', \
                      'Ezra' : u'Ездра', 'Neh' : u'Неемия', 'Esth' : u'Есфирь', 'Job' : u'Иов', 'Ps' : u'Псалтирь', \
                      'Prov' : u'Притчи', 'Eccl' : u'Екклесиаст', 'Song' : u'Песни Песней', 'Isa' : u'Исаия', 'Jer' : u'Иеремия', \
                      'Lam' : u'Плач Иеремии', 'Ezek' :u'Иезекииль', 'Dan' : u'Даниил', 'Hos' : u'Осия', 'Joel' : u'Иоиль', \
                      'Amos' : u'Амос', 'Obad' : u'Авдия', 'Jonah' : u'Иона', 'Mic' : u'Михей', 'Nah' : u'Наум' , 'Hab' : u'Аввакум', \
                      'Zeph' : u'Софония', 'Hag' : u'Аггей', 'Zech' : u'Захария', 'Mal' : u'Малахия', \
                      'PrMan' : u'Молитва Манассии', '1Esd' : u'1-я Ездры', 'Tob' : u'Товит', 'Jdt' : 'Джудит', 'Wis' : u'Мудрость', \
                      'Sir' : u'Sirach', 'EpJer' : u'Послание Джереми', 'Bar' : u'Барух', '1Macc' : u'1-я Маккавеи', \
                      '2Macc' :u'2-я Маккавеи', '3Macc' :u'3-я Маккавеи', '2Esd' : u'2-я Ездры', \
                      'Matt' : u'От Матфея', 'Mark' : u'От Марка', 'Luke': u'От Луки', 'John' : u'От Иоанна', 'Acts' : u'Деяния', \
                      'Rom' : 'К Римлянам', '1Cor' : u'1-е Коринфянам', '2Cor' : u'2-е Коринфянам', 'Gal' : u'К Галатам', \
                      'Eph' : 'К Ефесянам', 'Phil' : u'К Филиппийцам', 'Col' : u'К Колоссянам', '1Thess' : u'1-е Фессалоникийцам', \
                      '2Thess' : u'2-е Фессалоникийцам', '1Tim' : u'1-е Тимофею', '2Tim' : u'2-е Тимофею', 'Titus' : u'К Титу', \
                      'Phlm'  : u'К Филимону', 'Heb' : u'К Евреям', 'Jas' : u'Иакова' , '1Pet' : u'1-e Петра', '2Pet' : u'2-e Петра', \
                      '1John' : u'1-e Иоанна', '2John' : u'2-e Иоанна', '3John' : u'3-e Иоанна', 'Jude' : u'Иуда', 'Rev' : u'Откровение' }
        
        self.groups = ['', '', '', '']
        self.psalmTitle = ''
        self.chapterTitle = ''
        self.language = ''
        self.title = ''
        self.publisher = ''
        self.epub3 = False
        self.testamentIntro = False
        self.bibleIntro = False
        self.bookSubtitles = False
        self.psalmDivTitle = ''
        self.psalmDivSubtitle = ''
        self.optionalBreaks = False
        self.introInContents = True
                      
        cfile = codecs.open(configFilePath, 'r', encoding="utf-8")  
        config = cfile.read().strip()

        # Remove comments
        config = re.sub(r"#.*", "", config)
        #
        # Look for book names
        for book in self.books:
            regex = r"^\s*" + book + r"\s*=(.+)"
            m = re.search(regex, config, re.MULTILINE)
            if m:
                bookName = m.group(1).strip()
                self.books[book] = bookName
        #
        # Look for book groups
        for bookGroup in range(1,3):
            regex = r"^\s*group" + str(bookGroup) + r"\s*=(.+)"
            m = re.search(regex, config, re.MULTILINE|re.IGNORECASE)
            if m:
                self.groups[bookGroup] = m.group(1).strip()
        #
        # Look for Psalm and chapter heading patterns
        m = re.search(r"^\s*PsalmTitle=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            self.psalmTitle = m.group(1).strip()
        m = re.search(r"^\s*ChapterTitle=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            self.chapterTitle = m.group(1).strip()
        #
        # Look for metadata
        m = re.search(r"^\s*language=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            self.language = m.group(1).strip()
        m = re.search(r"^\s*publisher=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            self.publisher = m.group(1).strip()
        m = re.search(r"^\s*title=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            self.title = m.group(1).strip()
        #
        # Look for epub3 setting
        m = re.search(r"^\s*epub3=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            torf = m.group(1).strip().lower()
            if torf == 'true' or torf == 't' or torf == 'yes' or torf == 'y':
                self.epub3 = True
        #
        # Look for intro settings
        m = re.search(r"^\s*TestamentIntro=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            torf = m.group(1).strip().lower()
            if torf == 'true' or torf == 't' or torf == 'yes' or torf == 'y':
                self.testamentIntro = True
        m = re.search(r"^\s*BibleIntro=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            torf = m.group(1).strip().lower()
            if torf == 'true' or torf == 't' or torf == 'yes' or torf == 'y':
                self.bibleIntro = True
        m = re.search(r"^\s*IntroInContents=(.+)", config, re.MULTILINE|re.IGNORECASE)     
        if m:
            torf = m.group(1).strip().lower()
            if torf == 'false' or torf == 'f' or torf == 'no' or torf == 'n':
                self.introInContents = False  
                
        #
        # Look for settings related to title
        m = re.search(r"^\s*BookSubtitles=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            torf = m.group(1).strip().lower()
            if torf == 'true' or torf == 't' or torf == 'yes' or torf == 'y':
                self.bookSubtitles = True
         
        m = re.search(r"^\s*PsalmDivTitle=(.+)", config, re.MULTILINE|re.IGNORECASE)     
        if m:
            self.psalmDivTitle = m.group(1).strip() + '$'
            
        m = re.search(r"^\s*PsalmDivSubtitle=(.+)$", config, re.MULTILINE|re.IGNORECASE)     
        if m:
            self.psalmDivSubtitle = m.group(1).strip() + '$'
            
        #
        # Other settings
        m = re.search(r"^\s*OptionalBreaks=\s*(.+)", config, re.MULTILINE|re.IGNORECASE)     
        if m:
            torf = m.group(1).strip().lower()
            if torf == 'true' or torf == 't' or torf == 'yes' or torf == 'y':

                self.optionalBreaks = True        
        
    def bookTitle(self, bookRef):
        if bookRef in self.books:
            return self.books[bookRef]
        else:
            print 'Unknown book ', bookRef
            return ''
        
        
    def groupTitle(self, groupNum):
        if groupNum in range(1,3):
            return self.groups[groupNum]
        else:
            return ''
