<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:mods="http://www.loc.gov/mods/v3" exclude-result-prefixes="xs mods fgdc dcterms dwc dwr etd etd1 "
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:dwc="http://rs.tdwg.org/dwc/terms/" xmlns:dwr="http://rs.tdwg.org/dwc/xsd/simpledarwincore/"
    xmlns:etd="http://www.ndltd.org/standards/metadata/etdms/1.0" xmlns:etd1="http://www.ndltd.org/standards/metadata/etdms/1-0"
    xmlns:fgdc="http://www.fgdc.gov/schemas/metadata/fgdc-std-001-1998.xsd"
    >
    
    <!-- Thies xsl transform the CTDA I7 MODS xml to align with
         the MODS profile supported by the base I7-to-I8 migrate configuration. -->
    
    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
    
    <xsl:strip-space elements="*"/>

        <xsl:template match="/*">
        <!-- Manually create the root element and add any missing namespaces -->
        <xsl:element name="{name()}" namespace="{namespace-uri()}">
            <!-- Always add existing namespaces -->
            <xsl:copy-of select="namespace::*"/>

            <!-- Add xmlns:etd if missing -->
            <xsl:if test="not(namespace::*[. = 'http://www.ndltd.org/standards/metadata/etdms/1.0'])">
                <xsl:namespace name="etd">http://www.ndltd.org/standards/metadata/etdms/1.0</xsl:namespace>
            </xsl:if>

            <!-- Add xmlns:etd1 if missing -->
            <xsl:if test="not(namespace::*[. = 'http://www.ndltd.org/standards/metadata/etdms/1-0'])">
                <xsl:namespace name="etd1">http://www.ndltd.org/standards/metadata/etdms/1-0</xsl:namespace>
            </xsl:if>

            <!-- Apply templates to attributes and child nodes -->
            <xsl:apply-templates select="@*|node()"/>
        </xsl:element>
    </xsl:template>
  
    <!-- identity transform to copy through all nodes (except those with specific templates modifying them) -->
    <xsl:template match="/" exclude-result-prefixes="#all">
        <xsl:copy>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="* | @*" exclude-result-prefixes="#all">
        <xsl:copy>
            <xsl:apply-templates select="@* | * | text() | comment() | processing-instruction()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- keep comments and PIs -->
    <xsl:template match="comment() | processing-instruction()">
        <xsl:copy-of select="."/>
    </xsl:template>
    
    <!-- remove empty elements -->
    <xsl:template match="mods:name[not(normalize-space())] | mods:titleInfo[not(normalize-space())] |
        mods:typeOfResource[not(normalize-space())] | mods:tableOfContents[not(normalize-space())] | mods:abstract[not(normalize-space())] |
        mods:language[not(normalize-space())] | mods:tableOfcontents[not(normalize-space())] | mods:genre[not(normalize-space())] |
        mods:subject[(not(normalize-space()))] | mods:physicalDescription/*[(not(normalize-space()) and not(descendant::*[normalize-space()]))] |
        mods:originInfo/*[(not(normalize-space()) and not(descendant::*[normalize-space()]))] |
        mods:targetAudience[not(normalize-space())] | mods:note[not(normalize-space())] | mods:relatedItem[(not(normalize-space()))] | mods:location[(not(normalize-space()))] |
        mods:accessCondition[(not(normalize-space()))] | mods:recordInfo[not(normalize-space())]"/>
    
    <!-- CONCATENATE nonSort + title + subTitle-->
    <xsl:template match="mods:titleInfo">
        <titleInfo xmlns="http://www.loc.gov/mods/v3">
            <xsl:if test="@type">
                <xsl:attribute name="type"><xsl:value-of select="normalize-space(@type)"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="mods:title[@type]">
                <xsl:attribute name="type"><xsl:for-each select="mods:title"><xsl:value-of select="normalize-space(@type)"/></xsl:for-each></xsl:attribute>
            </xsl:if>
            <title>
                <xsl:if test="@displayLabel"><xsl:value-of select="normalize-space(@displayLabel)"/><xsl:text> </xsl:text></xsl:if>
                <xsl:if test="mods:nonSort"><xsl:value-of select="normalize-space(mods:nonSort)"/><xsl:text> </xsl:text></xsl:if>
                <xsl:value-of select="normalize-space(mods:title)"/>
                <xsl:if test="mods:subTitle"><xsl:text>: </xsl:text><xsl:value-of select="normalize-space(mods:subTitle)"/></xsl:if>
            </title>
            <xsl:if test="mods:partNumber">
                <partNumber><xsl:value-of select="normalize-space(mods:partNumber)"/></partNumber>
            </xsl:if>
        </titleInfo>
    </xsl:template>
    
    <xsl:template match="mods:name">
        <xsl:choose>
            <xsl:when test="not(@type)">
                <name type="personal" xmlns="http://www.loc.gov/mods/v3">
                    <xsl:variable name="newAuth">
                        <xsl:call-template name="newAuth"/>
                    </xsl:variable>
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:call-template name="nameParts"/>
                    <xsl:call-template name="creatorRole"/>
                </name>
            </xsl:when>
            <xsl:when test="not(mods:namePart)">
                <xsl:choose>
                    <xsl:when test="not(mods:role)">
                        <name xmlns="http://www.loc.gov/mods/v3">
                            <xsl:copy-of select="@type"/>
                            <xsl:variable name="newAuth">
                                <xsl:call-template name="newAuth"/>
                            </xsl:variable>
                            <xsl:if test="$newAuth!=''">
                                <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                            </xsl:if>
                            <namePart>
                                <xsl:value-of select="normalize-space(.)"/>
                            </namePart>
                        </name>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="mods:namePart=''"/>
            <xsl:otherwise>
                <name xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy-of select="@type"/>
                    <xsl:variable name="newAuth">
                        <xsl:call-template name="newAuth"/>
                    </xsl:variable>
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:call-template name="nameParts"/>
                    <xsl:call-template name="creatorRole"/>
                </name>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- STRIP ATTRIBUTES + UPDATE SOME VOCABULARY -->
    <xsl:template match="mods:typeOfResource">
        <xsl:copy>
            <xsl:choose>
                <xsl:when test="lower-case(.)='photographs'">photograph</xsl:when>
                <xsl:when test="lower-case(.)='software, multimedia'">software</xsl:when>
                <xsl:when test="lower-case(.)='sound recording'">audio</xsl:when>
                <xsl:when test="lower-case(.)='sound recording-musical'">audio musical</xsl:when>
                <xsl:when test="lower-case(.)='sound recording-nonmusical'">audio non-musical</xsl:when>
                <xsl:when test="lower-case(.)='three dimensional object'">artifact</xsl:when>
                <xsl:when test="parent::mods:originInfo"/>
                <xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="mods:typeOfResource[2]">
        <xsl:choose>
            <xsl:when test="../mods:typeOfResource"/>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:extension">
        <xsl:variable name="kingdom"><xsl:value-of select="normalize-space(mods:kingdom)"/></xsl:variable>
        <xsl:variable name="class"><xsl:value-of select="normalize-space(mods:class)"/></xsl:variable>
        <xsl:variable name="family"><xsl:value-of select="normalize-space(mods:family)"/></xsl:variable>
        <xsl:variable name="genus"><xsl:value-of select="normalize-space(mods:genus)"/></xsl:variable>
        <xsl:variable name="group"><xsl:value-of select="normalize-space(mods:group)"/></xsl:variable>
        <xsl:variable name="species"><xsl:value-of select="normalize-space(mods:species)"/></xsl:variable>
        <xsl:variable name="habitat"><xsl:value-of select="normalize-space(mods:habitat)"/></xsl:variable>
        <xsl:variable name="BoxName"><xsl:value-of select="normalize-space(mods:BoxName)"/></xsl:variable>
        <xsl:variable name="BoxNumber"><xsl:value-of select="normalize-space(mods:BoxNumber)"/></xsl:variable>
        
        <xsl:choose>
            <xsl:when test="etd:degree">
                <xsl:for-each select="etd:degree">
                    <extension xmlns="http://www.loc.gov/mods/v3">
                        <etd:degree>
                            <etd:name>
                                <xsl:value-of select="normalize-space(etd:name)"/>
                            </etd:name>
                            <etd:level>
                                <xsl:choose>
                                    <xsl:when test="lower-case(etd:level)='b.sc.'">undergraduate</xsl:when>
                                    <xsl:when test="lower-case(etd:level)='m.a.'">masters</xsl:when>
                                    <xsl:when test="lower-case(etd:level)='m.b.a.'">masters</xsl:when>
                                    <xsl:when test="lower-case(etd:level)='m.ed.'">masters</xsl:when>
                                    <xsl:when test="lower-case(etd:level)='m.n.r.e.s.'">masters</xsl:when>
                                    <xsl:when test="lower-case(etd:level)='m.s.w.'">masters</xsl:when>
                                    <xsl:when test="lower-case(etd:level)='m.sc.'">masters</xsl:when>
                                    <xsl:when test="lower-case(etd:level)='ph.d.'">doctoral</xsl:when>
                                    <xsl:otherwise><xsl:value-of select="normalize-space(etd:level)"/></xsl:otherwise>
                                </xsl:choose>
                            </etd:level>
                            <etd:discipline>
                                <xsl:value-of select="normalize-space(etd:discipline)"/>
                            </etd:discipline>
                            <etd:grantor>
                                <xsl:value-of select="normalize-space(etd:grantor)"/>
                            </etd:grantor>
                        </etd:degree>
                    </extension>
                </xsl:for-each>
            </xsl:when>
            <xsl:when test="$class!='' or $family!=''">
                <note xmlns="http://www.loc.gov/mods/v3">
                    <xsl:if test="$kingdom!=''"><xsl:text>Kingdom: </xsl:text><xsl:value-of select="normalize-space($kingdom)"/></xsl:if>
                    <xsl:if test="$class!=''"><xsl:text>Class: </xsl:text><xsl:value-of select="normalize-space($class)"/></xsl:if>
                    <xsl:if test="$class!=''"><xsl:text>; </xsl:text></xsl:if>
                    <xsl:if test="$family!=''"><xsl:text>Family: </xsl:text><xsl:value-of select="normalize-space($family)"/></xsl:if>
                    <xsl:if test="$family!=''"><xsl:text>; </xsl:text></xsl:if>
                    <xsl:if test="$genus!=''"><xsl:text>Genus: </xsl:text><xsl:value-of select="normalize-space($genus)"/><xsl:text>; </xsl:text></xsl:if>
                    <xsl:if test="$group!=''"><xsl:text>Group: </xsl:text><xsl:value-of select="normalize-space($group)"/><xsl:text>; </xsl:text></xsl:if>
                    <xsl:if test="$species!=''"><xsl:text>Species: </xsl:text><xsl:value-of select="normalize-space($species)"/><xsl:text>; </xsl:text></xsl:if>
                    <xsl:if test="$habitat!=''"><xsl:text>Habitat: </xsl:text><xsl:value-of select="normalize-space($habitat)"/></xsl:if>
                </note>
            </xsl:when>
            <xsl:when test="$BoxName!=''">
                <location xmlns="http://www.loc.gov/mods/v3">
                    <holdingSimple>
                        <copyInformation>
                            <shelfLocator><xsl:value-of select="normalize-space($BoxName)"/><xsl:text>, Number </xsl:text><xsl:value-of select="normalize-space(../mods:extension/mods:BoxNumber)"/></shelfLocator>
                        </copyInformation>
                    </holdingSimple>
                </location>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:abstract">
        <xsl:choose>
            <xsl:when test="@displayLabel='academic'">
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="starts-with(@displayLabel,'Administrative History')">
                <note type="admin" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></note>
            </xsl:when>
            <xsl:when test="@type='custodial history'">
                <note type="provenance" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></note>
            </xsl:when>
            <xsl:when test="@type='immediate source of acquisition'">
                <note type="acquisition" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></note>
            </xsl:when>
            <xsl:when test="@type='office of origin'">
                <note type="ownership" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></note>
            </xsl:when>
            <xsl:when test="@type='scope and content'">
                <note type="scope and content" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></note>
            </xsl:when>
            <xsl:when test="mods:accessCondition[@type='use and reproduction']">
                <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
            </xsl:when>
            <xsl:when test="@type='arrangement'">
                <physicalDescription xmlns="http://www.loc.gov/mods/v3">
                    <note><xsl:value-of select="normalize-space(@displayLabel)"/><xsl:text>: </xsl:text><xsl:value-of select="normalize-space(.)"/></note>
                </physicalDescription>
            </xsl:when>
            <xsl:when test="@displayLabel='Track Listing'">
                <tableOfContents xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></tableOfContents>
            </xsl:when>
            <xsl:otherwise>
                <abstract type="description" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></abstract>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:tableofcontents">
        <tableOfContents xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></tableOfContents>
    </xsl:template>
    
    <xsl:template match="mods:targetAudience">
        <xsl:choose>
            <xsl:when test="starts-with(.,'Beginner')">
                <targetAudience xmlns="http://www.loc.gov/mods/v3"><xsl:text>Beginner learners</xsl:text></targetAudience>
            </xsl:when>
            <xsl:otherwise>
                <targetAudience xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></targetAudience>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:language">
        <xsl:choose>
            <xsl:when test="contains(., ';')">
                <xsl:for-each select="tokenize(., ';')">
                    <language xmlns="http://www.loc.gov/mods/v3">
                        <languageTerm type="text">
                            <xsl:call-template name="langToText"/>
                        </languageTerm>
                    </language>
                </xsl:for-each>
            </xsl:when>
            <xsl:when test="contains(., ',')">
                <xsl:for-each select="tokenize(., ',')">
                    <language xmlns="http://www.loc.gov/mods/v3">
                        <languageTerm type="text">
                            <xsl:call-template name="langToText"/>
                        </languageTerm>
                    </language>
                </xsl:for-each>
            </xsl:when>
            <xsl:when test="contains(., '/')">
                <xsl:for-each select="tokenize(., '/')">
                    <language xmlns="http://www.loc.gov/mods/v3">
                        <languageTerm type="text">
                            <xsl:call-template name="langToText"/>
                        </languageTerm>
                    </language>
                </xsl:for-each>
            </xsl:when>
            <xsl:when test="mods:languageTerm[@type='code']"/>
            <xsl:otherwise>
                <language xmlns="http://www.loc.gov/mods/v3">
                    <languageTerm type="text">
                        <xsl:call-template name="langToText"/>
                    </languageTerm>
                </language>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:identifier">
        <xsl:choose>
            <xsl:when test="not(@type)">
                <identifier type='local' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></identifier>
            </xsl:when>
            <xsl:when test="@type=('legacy','local access number','other')">
                <identifier type='local' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></identifier>
            </xsl:when>
            <xsl:when test="starts-with(@type, 'access')">
                <identifier type='access' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></identifier>
            </xsl:when>
            <xsl:when test="@type=('bib-number','lac')">
                <recordInfo xmlns="http://www.loc.gov/mods/v3">
                    <recordInfoNote><xsl:value-of select="normalize-space(.)"/></recordInfoNote>
                </recordInfo>
            </xsl:when>
            <xsl:when test="@type='record'">
                <location xmlns="http://www.loc.gov/mods/v3">
                    <holdingSimple>
                        <copyInformation>
                            <electronicLocator><xsl:value-of select="normalize-space(.)"/></electronicLocator>
                        </copyInformation>
                    </holdingSimple>
                </location>
            </xsl:when>
            <xsl:when test="@type='repository'">
                <relatedItem type="host" xmlns="http://www.loc.gov/mods/v3">
                    <titleInfo>
                        <title><xsl:value-of select="normalize-space(.)"/></title>
                    </titleInfo>
                </relatedItem>
            </xsl:when>
            <xsl:when test="@type='u2'">
                <extension xmlns="http://www.loc.gov/mods/v3">
                    <etd:degree>
                        <etd:discipline><xsl:value-of select="normalize-space(.)"/></etd:discipline>
                    </etd:degree>
                </extension>
            </xsl:when>
            <xsl:when test="@type='eissn'">
                <xsl:choose>
                    <xsl:when test="not(//mods:identifier[@type='issn'])">
                        <identifier type='issn' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></identifier>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="@type=('lcc','lccn')">
                <classification authority='lcc' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></classification>
            </xsl:when>
            <xsl:when test="@type='uri'">
                <xsl:choose>
                    <xsl:when test="parent::mods:location">
                        <url xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></url>
                    </xsl:when>
                    <xsl:when test="not(@invalid)">
                        <identifier type='uri' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></identifier>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="@type=('citekey','uuid','u1')"/>
            <xsl:otherwise>
                <identifier xmlns="http://www.loc.gov/mods/v3">
                    <xsl:attribute name="type"><xsl:value-of select="normalize-space(@type)"/></xsl:attribute>
                    <xsl:value-of select="normalize-space(.)"/>
                </identifier>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:subject">
        <xsl:variable name="subAuth">
            <xsl:call-template name="newAuth"/>
        </xsl:variable>
        <xsl:for-each select="*">
    <xsl:choose>
        <xsl:when test="(self::mods:geographic, self::mods:temporal, self::mods:hierarchicalGeographic, self::mods:cartographics, self::mods:geographicCode)">
            <subject xmlns="http://www.loc.gov/mods/v3">
                <xsl:variable name="newAuth">
                    <xsl:call-template name="newAuth"/>
                </xsl:variable>
                <xsl:copy>
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:if test="$subAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:copy-of select="* | text()"/>
                </xsl:copy>
            </subject>
        </xsl:when>
        <xsl:when test="self::mods:subject">
            <subject xmlns="http://www.loc.gov/mods/v3">
                <xsl:variable name="newAuth">
                    <xsl:call-template name="newAuth"/>
                </xsl:variable>
                <xsl:if test="$newAuth!=''">
                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                </xsl:if>
                <xsl:if test="$subAuth!=''">
                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                </xsl:if>
                <xsl:copy-of select="* | text()"/>
            </subject>
        </xsl:when>
        <xsl:when test="self::mods:topic">
            <xsl:variable name="newAuth">
                <xsl:call-template name="newAuth"/>
            </xsl:variable>
            <xsl:choose>
                <xsl:when test="contains(., ';')">
                    <xsl:for-each select="tokenize(., ';')">
                        <subject xmlns="http://www.loc.gov/mods/v3">
                            <topic>
                                <xsl:if test="$newAuth!=''">
                                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                                </xsl:if>
                                <xsl:if test="$subAuth!=''">
                                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                                </xsl:if>
                                <xsl:value-of select="normalize-space(.)"/>
                            </topic>
                        </subject>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <subject xmlns="http://www.loc.gov/mods/v3">
                        <topic>
                            <xsl:if test="$newAuth!=''">
                                <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                            </xsl:if>
                            <xsl:if test="$subAuth!=''">
                                <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                            </xsl:if>
                            <xsl:value-of select="normalize-space(.)"/>
                        </topic>
                    </subject>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:when>
        <xsl:when test="self::mods:name[@type]">
            <xsl:if test="mods:namePart">
            <subject xmlns="http://www.loc.gov/mods/v3">
                <xsl:variable name="newAuth">
                    <xsl:call-template name="newAuth"/>
                </xsl:variable>
                <xsl:copy>
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:if test="$subAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </subject>
            </xsl:if>
            <xsl:if test="not(mods:namePart)">
                <subject xmlns="http://www.loc.gov/mods/v3">
                    <name>
                        <xsl:attribute name="type"><xsl:value-of select="normalize-space(@type)"/></xsl:attribute>
                        <namePart>
                            <xsl:value-of select="normalize-space(.)"/>
                        </namePart>
                    </name>
                </subject>
            </xsl:if>
        </xsl:when>
        <xsl:when test="self::mods:name[not(@type_)]">
                <subject xmlns="http://www.loc.gov/mods/v3">
                    <xsl:variable name="newAuth">
                        <xsl:call-template name="newAuth"/>
                    </xsl:variable>
                    <xsl:copy>
                        <xsl:if test="$newAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:if test="$subAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:attribute name="type">personal</xsl:attribute>
                        <xsl:copy-of select="@* | * | text()"/>
                    </xsl:copy>
                </subject>
        </xsl:when>
        <xsl:when test="self::mods:namePart">
            <subject xmlns="http://www.loc.gov/mods/v3">
                <xsl:variable name="newAuth">
                    <xsl:call-template name="newAuth"/>
                </xsl:variable>
                <name type="corporate">
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:if test="$subAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
                </name>
            </subject>
        </xsl:when>
        <xsl:when test="(self::mods:titleInfo,self::mods:identifier)">
            <subject xmlns="http://www.loc.gov/mods/v3">
                <xsl:variable name="newAuth">
                    <xsl:call-template name="newAuth"/>
                </xsl:variable>
                <xsl:if test="$newAuth!=''">
                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                </xsl:if>
                <xsl:if test="$subAuth!=''">
                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($subAuth)"/></xsl:attribute>
                </xsl:if>
                <topic>
                    <xsl:value-of select="normalize-space(.)"/>
                </topic>
            </subject>
        </xsl:when>
        <xsl:when test="(self::mods:description, self::mods:genre)"/>
    </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="mods:place">
        <xsl:choose>
            <xsl:when test="not(mods:placeTerm)">
                <xsl:choose>
                    <xsl:when test="not(../mods:place/mods:placeTerm)">
                        <place xmlns="http://www.loc.gov/mods/v3">
                            <placeTerm type="text">
                                <xsl:value-of select="(.)"/>
                            </placeTerm>
                        </place>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="mods:placeTerm[@authority='marccountry']"/>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:dateCreated">
        <xsl:choose>
            <xsl:when test="../mods:dateIssued">
                <dateCreated xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy-of select="@point"/>
                    <xsl:variable name="newDate">
                        <xsl:call-template name="format-dates">
                            <xsl:with-param name="date-value" select="normalize-space(.)"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:call-template name="qualifier">
                        <xsl:with-param name="qual-date" select="normalize-space($newDate)"/>
                    </xsl:call-template>
                </dateCreated>
            </xsl:when>
            <xsl:otherwise>
                <dateIssued xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy-of select="@point"/>
                    <xsl:variable name="newDate">
                        <xsl:call-template name="format-dates">
                            <xsl:with-param name="date-value" select="normalize-space(.)"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:call-template name="qualifier">
                        <xsl:with-param name="qual-date" select="normalize-space($newDate)"/>
                    </xsl:call-template>
                </dateIssued>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    
    <!-- testing out date cast and formatting here -->
    <xsl:template match="mods:dateIssued[normalize-space()] | mods:dateCaptured[normalize-space()] | mods:dateModified[normalize-space()] | mods:dateOther[normalize-space()] | mods:copyrightDate[normalize-space()] | mods:recordCreationDate[normalize-space()] | mods:recordChangeDate[normalize-space()]" exclude-result-prefixes="#all">

             <xsl:variable name="element-name" select="local-name()"/>
             
             <xsl:element name="{$element-name}" xmlns="http://www.loc.gov/mods/v3">
                 <xsl:copy-of select="@point"/>
                 
                 <xsl:variable name="newDate">
                     <xsl:call-template name="format-dates">
                         <xsl:with-param name="date-value" select="normalize-space(.)"/>
                     </xsl:call-template>
                 </xsl:variable>
                 

                 <xsl:call-template name="qualifier">
                     <xsl:with-param name="qual-date" select="normalize-space($newDate)"/>
                 </xsl:call-template>
                 
             </xsl:element>
    </xsl:template>
    
    <xsl:template name="format-dates" exclude-result-prefixes="#all">
        <!-- format all valid date values as iso8601 -->
        <xsl:param name="date-value" as="xs:string"/>
        <xsl:variable name="month-name-to-number">
            <months>
                <month><name>january</name><number>01</number></month>
                <month><name>february</name><number>02</number></month>
                <month><name>march</name><number>03</number></month>
                <month><name>april</name><number>04</number></month>
                <month><name>may</name><number>05</number></month>
                <month><name>june</name><number>06</number></month>
                <month><name>july</name><number>07</number></month>
                <month><name>august</name><number>08</number></month>
                <month><name>september</name><number>09</number></month>
                <month><name>october</name><number>10</number></month>
                <month><name>november</name><number>11</number></month>
                <month><name>december</name><number>12</number></month>
            </months>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$date-value castable as xs:date">
                <xsl:value-of select="format-date($date-value cast as xs:date,'[Y0001]-[M01]-[D01]')"/>
            </xsl:when>
            
            <!-- REMOVE VALUE -->
            <!-- Remove non-date values -->
            <xsl:when test="lower-case($date-value)=('?','n.a.','n.d.','no date','test','unknown','[unknown]')"/>    
            
            <!-- START WITH ~ -->
            
            <!-- change "~YYY0s" | change to YYYX~ -->
            <xsl:when test="matches($date-value,'^~\d{3}[0]s$')">
                <xsl:value-of select="concat((substring($date-value,2,3)),'X~')"/>
            </xsl:when>
            
            
            <!-- fix YYYY-YYYY ranges to YYYY/YYYY -->
            <xsl:when test="matches($date-value,'^\d{4}-\d{4}$')">
                <xsl:value-of select="concat(tokenize($date-value,'-')[1],'/',tokenize($date-value,'-')[2])"/>
            </xsl:when>
            
            <!-- change MM/D/YYYY | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{2}/\d{1}/\d{4}$')">
                <xsl:value-of select="concat(tokenize($date-value,'/')[3],'-',tokenize($date-value,'/')[1],'-0',tokenize($date-value,'/')[2])"/>
            </xsl:when>
            
            <!-- change YYYY \-\- MM | change to YYYY-MM -->
            <xsl:when test="matches($date-value,'^\d{4}\s\-\-\s\d{2}$')">
                <xsl:value-of select="concat(tokenize($date-value,' -- ')[1],'-',tokenize($date-value,' -- ')[2])"/>
            </xsl:when>
            
            <!-- change YYYY-M | change to YYYY-MM -->
            <xsl:when test="matches($date-value,'^\d{4}\-\d{1}$')">
                <xsl:value-of select="concat(tokenize($date-value,'-')[1],'-0',tokenize($date-value,'-')[2])"/>
            </xsl:when>
            
            <!-- change YYYY-M-D | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{4}\-\d{1}\-\d{1}$')">
                <xsl:value-of select="concat(tokenize($date-value,'-')[1],'-0',tokenize($date-value,'-')[2],'-0',tokenize($date-value,'-')[3])"/>
            </xsl:when>
            
            <!-- change YYYY-M-DD | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{4}\-\d{1}\-\d{2}$')">
                <xsl:value-of select="concat(tokenize($date-value,'-')[1],'-0',tokenize($date-value,'-')[2],'-',tokenize($date-value,'-')[3])"/>
            </xsl:when>
            
            <!-- change YYYY-MM-D | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{4}\-\d{2}\-\d{1}$')">
                <xsl:value-of select="concat(tokenize($date-value,'-')[1],'-',tokenize($date-value,'-')[2],'-0',tokenize($date-value,'-')[3])"/>
            </xsl:when>
            
            <!-- change YYYY/M/DD | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{4}/\d{1}/\d{2}$')">
                <xsl:value-of select="concat(tokenize($date-value,'/')[1],'-0',tokenize($date-value,'/')[2],'-',tokenize($date-value,'/')[3])"/>
            </xsl:when>
            
            <!-- change YYYY/MM/DD | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{4}/\d{2}/\d{2}$')">
                <xsl:value-of select="concat(tokenize($date-value,'/')[1],'-',tokenize($date-value,'/')[2],'-',tokenize($date-value,'/')[3])"/>
            </xsl:when>
            
            <!-- change YYYY-MM-DD-YYYY-MM-DD | change to YYYY-MM-DD/YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{4}-\d{2}-\d{2}\-\d{4}-\d{2}-\d{2}$')">
                <xsl:value-of select="concat(tokenize($date-value,'-')[1],'-',tokenize($date-value,'-')[2],'-',tokenize($date-value,'-')[3],'/',tokenize($date-value,'-')[4],'-',tokenize($date-value,'-')[5],'-',tokenize($date-value,'-')[6])"/>
            </xsl:when>
            
            <!-- change YYMMDD | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{6}$')">
                <xsl:value-of select="concat('20',(substring($date-value,1,2)),'-',(substring($date-value,3,2)),'-',(substring($date-value,5,2)))"/>
            </xsl:when>

            <!-- change YYYYMMDD | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{8}$')">
                <xsl:value-of select="concat((substring($date-value,1,4)),'-',(substring($date-value,5,2)),'-',(substring($date-value,7,2)))"/>
            </xsl:when>
            
            <!-- change YYYYMMDDHHMMSS.0 | change to YYYY-MM-DDTHH:MM:SS -->
            <xsl:when test="matches($date-value,'^\d{14}\.0$')">
                <xsl:value-of select="concat((substring($date-value,1,4)),'-',(substring($date-value,5,2)),'-',(substring($date-value,7,2)),'T',(substring($date-value,9,2)),':',(substring($date-value,11,2)),':',(substring($date-value,13,2)))"/>
            </xsl:when>
            
            <!-- change YYYY- | change to YYYY/.. -->
            <xsl:when test="matches($date-value,'^\d{4}\-$')">
                <xsl:value-of select="concat((substring($date-value,1,4)),'/..')"/>
            </xsl:when>
            
            <!-- change from "YYYYs" | change to YYYX~ -->
            <xsl:when test="matches($date-value,'^\d{4}s$')">
                <xsl:value-of select="concat((substring($date-value,1,3)),'X~')"/>
            </xsl:when> 
            
            <!-- [DATE] -->
            <!-- change from [YYYY] | change to YYYY~ -->
            <xsl:when test="matches($date-value,'^\[\d{4}\]$')">
                <xsl:value-of select="concat((substring($date-value,2,4)),'~')"/>
            </xsl:when>
            
            <!-- change from [YYYYs?] | change to YYYX? -->
            <xsl:when test="matches($date-value,'^\[\d{4}s\?\]$')">
                <xsl:value-of select="concat((substring($date-value,2,3)),'X?')"/>
            </xsl:when>
            
            <!-- change from YYYY. | change to YYYY-->
            <xsl:when test="matches($date-value,'^\d{4}\.$')">
                <xsl:value-of select="(substring($date-value,1,4))"/>
            </xsl:when>
            
            <!-- change from YYYY..YYYY | change to YYYY/YYYY~ -->
            <xsl:when test="matches($date-value,'^\d{4}\.\.\d{4}$')">
                <xsl:value-of select="concat((substring($date-value,1,4)),'/',(substring($date-value,7,4)))"/>
            </xsl:when>
            
            <!-- change from after YYYY | change to YYYY/.. -->
            <xsl:when test="matches($date-value,'^after \d{4}$')">
                <xsl:value-of select="concat((substring($date-value,7,10)),'/..')"/>
            </xsl:when>
            
            <!-- change from before YYYY | change to ../YYYY -->
            <xsl:when test="matches($date-value,'^before \d{4}$')">
                <xsl:value-of select="concat('../', (substring($date-value,8,10)))"/>
            </xsl:when>
            
            <!-- change from ca. YYYY | change to YYYY~ -->
            <xsl:when test="matches($date-value,'^ca\. \d{4}$')">
                <xsl:value-of select="concat((substring($date-value,4,7)),'~')"/>
            </xsl:when>
            
            <!-- change from cYYYY | change to YYYY~ -->
            <xsl:when test="matches($date-value,'^c\d{4}$')">
                <xsl:value-of select="concat((substring($date-value,2,4)),'~')"/>
            </xsl:when>
            
            <!-- change from circa YYYY-YYYY | change to YYYY/YYYY~ -->
            <xsl:when test="matches($date-value,'^circa\s\d{4}-\d{4}$')">
                <xsl:value-of select="concat((substring($date-value,7,4)),'/',(substring($date-value,12,4)),'~')"/>
            </xsl:when>
            
            <!-- change from "circa YYYYs" | change to YYYX~ -->
            <xsl:when test="matches($date-value,'^circa\s\d{4}s$')">
                <xsl:value-of select="concat((substring($date-value,7,3)),'X~')"/>
            </xsl:when> 
            
            <!-- change from "circa YYYY" | change to YYYX~ -->
            <xsl:when test="matches($date-value,'^circa\s\d{4}$')">
                <xsl:value-of select="concat((substring($date-value,7,4)),'~')"/>
            </xsl:when>
            
            
            <!-- change from circa YYYY-YYYY | change to YYYY/YYYY~ -->
            <xsl:when test="matches($date-value,'^circa\s\d{4}-\d{4}$')">
                <xsl:value-of select="concat((substring($date-value,7,4)),'/',(substring($date-value,12,4)),'~')"/>
            </xsl:when>
            
            <!-- change from "YYYY-MM-DDTHH:MM:SSZ" | change to YYYY-MM-DDTHH:MM:SS -->
            <xsl:when test="matches($date-value,'^\d{4}\-\d{2}\-\d{2}T\d{2}:\d{2}:\d{2}Z$')">
                <xsl:value-of select="(substring($date-value,1,19))"/>
            </xsl:when>
            
            <!-- change from "YYYY-MM-DD HH:MM:SS" | change to YYYY-MM-DDTHH:MM:SS -->
            <xsl:when test="matches($date-value,'^\d{4}\-\d{2}\-\d{2}\s\d{2}:\d{2}:\d{2}$')">
                <xsl:value-of select="concat(tokenize($date-value,' ')[1],'T',tokenize($date-value,' ')[2])"/>
            </xsl:when> 
            
            <!-- change from "Summer YYYY" | change to YYYY-22 -->
            <xsl:when test="matches($date-value,'^Summer\s\d{4}$')">
                <xsl:value-of select="concat(tokenize($date-value,' ')[2],'-22')"/>
            </xsl:when> 

            <!-- input as: D Month YYYY | change to YYYY-MM-DD -->
            <xsl:when test="matches(lower-case($date-value),'^\d{1}\s(january|february|march|april|may|june|july|august|september|october|november|december)\s\d{4}$')">
                <xsl:variable name="month" select="$month-name-to-number/months/month[name[lower-case(.) = lower-case(tokenize($date-value,' ')[2])]]/number"/>
                <xsl:variable name="day" select="concat('0',tokenize($date-value,' ')[1])"/>
                <xsl:variable name="year" select="tokenize($date-value,' ')[3]"/>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)"/>
            </xsl:when>

            <!-- input as: DD Month YYYY | change to YYYY-MM-DD -->
            <xsl:when test="matches(lower-case($date-value),'^\d{2}\s(january|february|march|april|may|june|july|august|september|october|november|december)\s\d{4}$')">
                <xsl:variable name="month" select="$month-name-to-number/months/month[name[lower-case(.) = lower-case(tokenize($date-value,' ')[2])]]/number"/>
                <xsl:variable name="day" select="tokenize($date-value,' ')[1]"/>
                <xsl:variable name="year" select="tokenize($date-value,' ')[3]"/>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)"/>
            </xsl:when>
            
            <!-- input as: month DD, YYYY | change to YYYY-MM-DD -->
            <xsl:when test="matches(lower-case(.),'^(january|february|march|april|may|june|july|august|september|october|november|december)\s\d{2},\s\d{4}$')">
                <xsl:variable name="month" select="$month-name-to-number/months/month[name[lower-case(.) = lower-case(tokenize($date-value,' ')[1])]]/number"/>
                <xsl:variable name="day" select="substring(tokenize(.,' ')[2],1,2)"/>
                <xsl:variable name="year" select="tokenize($date-value,' ')[3]"/>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)"/>
            </xsl:when>
            
            <!-- INCLUDE / -->
            <!-- change MM/D/YYYY | change to YYYY-MM-DD -->
            <xsl:when test="matches($date-value,'^\d{2}/\d{1}/\d{4}$')">
                <xsl:value-of select="concat(tokenize($date-value,'/')[3],'-',tokenize($date-value,'/')[1],'-0',tokenize($date-value,'/')[2])"/>
            </xsl:when>
            
            <!-- TRANSFORM TEXT DATES TO NUMERIC DATES -->
            <!-- input as: 'YYYY month D' | change to YYYY-MM-DD -->
            <xsl:when test="matches(lower-case($date-value),'^\d{4}\s(january|february|march|april|may|june|july|august|september|october|november|december) \d{1}$')">
                <xsl:variable name="month" select="$month-name-to-number/months/month[name[lower-case(.) = lower-case(tokenize($date-value,' ')[2])]]/number"/>
                <xsl:variable name="day" select="concat('0',tokenize($date-value,' ')[3])"/>
                <xsl:variable name="year" select="tokenize($date-value,' ')[1]"/>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)"/>
            </xsl:when>
            
            <!-- month YYYY to YYYY-MM -->
            <xsl:when test="matches(lower-case(.),'^(january|february|march|april|may|june|july|august|september|october|november|december)\s\d{4}$')">
                <xsl:variable name="month" select="$month-name-to-number/months/month[name[lower-case(.) = lower-case(tokenize($date-value,' ')[1])]]/number"/>
                <xsl:variable name="year" select="tokenize(.,' ')[2]"/>
                <xsl:value-of select="concat($year,'-',$month)"/>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:value-of select="normalize-space(.)"/>
            </xsl:otherwise>
            
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="qualifier">
        <xsl:param name="qual-date" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="lower-case(@qualifier) = 'approximate'">
                <xsl:choose>
                    <xsl:when test="ends-with($qual-date, '~')"><xsl:value-of select="normalize-space($qual-date)"/></xsl:when>
                    <xsl:when test="ends-with($qual-date, '?')"><xsl:value-of select="substring($qual-date, 1, string-length($qual-date) - 1)"/><xsl:text>%</xsl:text></xsl:when>
                    <xsl:otherwise><xsl:value-of select="normalize-space($qual-date)"/><xsl:text>~</xsl:text></xsl:otherwise>
                </xsl:choose>               
            </xsl:when>
            <xsl:when test="lower-case(@qualifier) = 'questionable'">
                <xsl:choose>
                    <xsl:when test="ends-with($qual-date, '?')"><xsl:value-of select="normalize-space($qual-date)"/></xsl:when>
                    <xsl:when test="ends-with($qual-date, '~')"><xsl:value-of select="substring($qual-date, 1, string-length($qual-date) - 1)"/><xsl:text>%</xsl:text></xsl:when>
                    <xsl:otherwise><xsl:value-of select="normalize-space($qual-date)"/><xsl:text>?</xsl:text></xsl:otherwise>
                </xsl:choose> 
            </xsl:when>
            <xsl:when test="lower-case(@qualifier) = 'before'">
                <xsl:text>../</xsl:text><xsl:value-of select="normalize-space($qual-date)"/>
            </xsl:when>
            <xsl:when test="lower-case(@qualifier) = 'after'">
                <xsl:value-of select="normalize-space($qual-date)"/><xsl:text>/..</xsl:text>
            </xsl:when>
            <xsl:when test="lower-case(@qualifier) = 'estimate'">
                <xsl:choose>
                    <xsl:when test="ends-with($qual-date, '~')"><xsl:value-of select="normalize-space($qual-date)"/></xsl:when>
                    <xsl:when test="ends-with($qual-date, '?')"><xsl:value-of select="substring($qual-date, 1, string-length($qual-date) - 1)"/><xsl:text>%</xsl:text></xsl:when>
                    <xsl:otherwise><xsl:value-of select="normalize-space($qual-date)"/><xsl:text>~</xsl:text></xsl:otherwise>
                </xsl:choose> 
            </xsl:when>
            <xsl:when test="lower-case(@qualifier) = 'inferred'">
                <xsl:choose>
                    <xsl:when test="ends-with($qual-date, '~')"><xsl:value-of select="normalize-space($qual-date)"/></xsl:when>
                    <xsl:when test="ends-with($qual-date, '?')"><xsl:value-of select="substring($qual-date, 1, string-length($qual-date) - 1)"/><xsl:text>%</xsl:text></xsl:when>
                    <xsl:otherwise><xsl:value-of select="normalize-space($qual-date)"/><xsl:text>~</xsl:text></xsl:otherwise>
                </xsl:choose> 
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="normalize-space($qual-date)"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    
<!--    <xsl:template match="mods:dateModified">
        <xsl:choose>
            <xsl:when test="contains(., ';')">
                <xsl:for-each select="tokenize(., ';')">
                    <dateModified xmlns="http://www.loc.gov/mods/v3">
                        <xsl:value-of select="normalize-space(.)"/>
                    </dateModified>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                    <xsl:copy>
                        <xsl:copy-of select="* | text()"/>
                    </xsl:copy>
                </xsl:otherwise>

            
        </xsl:choose>
    </xsl:template>-->
    
    <xsl:template match="mods:edition">
        <xsl:copy>
            <xsl:copy-of select="* | text()"/>
        </xsl:copy>
    </xsl:template>
    
    
    <xsl:template name="note">
        <xsl:for-each select="mods:note">
            <xsl:choose>
                <xsl:when test="mods:noteTerm">
                    <xsl:copy>
                        <xsl:text>Condition: </xsl:text><xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </xsl:when>
                <xsl:when test="@displayLabel!=''">
                    <xsl:copy>
                        <xsl:value-of select="normalize-space(@displayLabel)"/><xsl:text>: </xsl:text><xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </xsl:when>
                <xsl:when test="@type!=''">
                    <xsl:copy>
                        <xsl:value-of select="normalize-space(@type)"/><xsl:text>: </xsl:text><xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy>
                        <xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    <xsl:template name="note_condition">
        <xsl:for-each select="mods:note_condition">
            <note xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></note>
        </xsl:for-each>
    </xsl:template>
    
    
    <xsl:template match="mods:note">
        <xsl:if test="@type='descriptive'">
            <extension xmlns="http://www.loc.gov/mods/v3">
                <etd:degree>
                    <etd:discipline>
                        <xsl:value-of select="normalize-space(.)"/>
                    </etd:discipline>
                </etd:degree>
            </extension>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="parent::mods:originInfo"/>
            <xsl:when test="@displayLabel!=''">
                <xsl:choose>
                    <xsl:when test="@displayLabel=('PAASH Subject Headings','Subject Headings')">
                        <note displayLabel="keywords" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="lower-case(.)='peer reviewed'">
                        <note displayLabel="Peer Reviewed" xmlns="http://www.loc.gov/mods/v3">Yes</note>
                    </xsl:when>
                    <xsl:when test="lower-case(.)='not peer reviewed'"/>
                    <xsl:otherwise>
                        <note xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(@displayLabel)"/><xsl:text>: </xsl:text><xsl:value-of select="(.)"/></note>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="@type!=''">
                <xsl:choose>
                    <xsl:when test="starts-with(lower-case(@type), 'acquisition')">
                        <note type="acquisition" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="@type='author keyword'">
                        <note displayLabel="keywords" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="@type=('additional physical form','admin','bibliography','creation/production credits','funding','language','ownership','performers','preferred citation','provenance','statement of responsibility','system details','venue','version identification')">
                        <note xmlns="http://www.loc.gov/mods/v3"><xsl:attribute name="type"><xsl:value-of select="(@type)"/></xsl:attribute><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="starts-with(lower-case(@type), 'exhibition')">
                        <note type="exhibitions" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="lower-case(@type)='restriction'">
                        <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(.)"/></accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(@type)='statementofresponsibility'">
                        <note type="statement of responsibility" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="lower-case(@type)='commercial_applications'">
                        <note xmlns="http://www.loc.gov/mods/v3"><xsl:text>Commercial Applications: </xsl:text><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="lower-case(@type)='sponsorship'">
                        <note type="funding" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(.)"/></note>
                    </xsl:when>
                    <xsl:when test="lower-case(@type)='descriptive'"/>
                    <xsl:otherwise>
                        <note xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="(@type)"/><xsl:text>: </xsl:text><xsl:value-of select="(.)"/></note>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    
    <xsl:template match="mods:physicalDescription">
        <xsl:for-each select="mods:genre"><genre xmlns="http://www.loc.gov/mods/v3"><xsl:copy-of select="@* | * | text()"/></genre></xsl:for-each>
        <xsl:for-each select="mods:location">
            <location xmlns="http://www.loc.gov/mods/v3">
                <xsl:copy-of select="@* | * | text()"/>
            </location></xsl:for-each>
        <xsl:copy>
        <xsl:choose>
            <xsl:when test="descendant::*">
                <xsl:for-each select="mods:reformattingQuality">
                    <xsl:copy>
                        <xsl:variable name="newAuth">
                            <xsl:call-template name="newAuth"/>
                        </xsl:variable>
                        <xsl:if test="$newAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="normalize-space(.)"/>
                    ac</xsl:copy>
                </xsl:for-each>
                <xsl:for-each select="mods:digitalOrigin">
                    <xsl:copy>
                        <xsl:variable name="newAuth">
                            <xsl:call-template name="newAuth"/>
                        </xsl:variable>
                        <xsl:if test="$newAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </xsl:for-each>
                <xsl:call-template name="extent"/>
                <xsl:call-template name="note"/>
                <xsl:call-template name="note_condition"/>
                <xsl:for-each select="mods:form">
                    <xsl:copy>
                        <xsl:variable name="newAuth">
                            <xsl:call-template name="newAuth"/>
                        </xsl:variable>
                        <xsl:if test="$newAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </xsl:for-each>
                <xsl:for-each select="mods:quality">
                    <reformattingQuality xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></reformattingQuality>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <note xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></note>
            </xsl:otherwise>
        </xsl:choose>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="mods:form">
        <xsl:choose>
            <xsl:when test="parent::mods:physicalDescription">
                <xsl:copy>
                    <xsl:variable name="newAuth">
                        <xsl:call-template name="newAuth"/>
                    </xsl:variable>
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <physicalDescription xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy>
                        <xsl:variable name="newAuth">
                            <xsl:call-template name="newAuth"/>
                        </xsl:variable>
                        <xsl:if test="$newAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </physicalDescription>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:reformattingQuality">
        <xsl:choose>
            <xsl:when test="parent::mods:physicalDescription">
                <xsl:copy>
                    <xsl:variable name="newAuth">
                        <xsl:call-template name="newAuth"/>
                    </xsl:variable>
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <physicalDescription xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy>
                        <xsl:variable name="newAuth">
                            <xsl:call-template name="newAuth"/>
                        </xsl:variable>
                        <xsl:if test="$newAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </physicalDescription>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="mods:digitalOrigin">
        <xsl:choose>
            <xsl:when test="parent::mods:physicalDescription">
                <xsl:copy>
                    <xsl:variable name="newAuth">
                        <xsl:call-template name="newAuth"/>
                    </xsl:variable>
                    <xsl:if test="$newAuth!=''">
                        <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                    </xsl:if>
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <physicalDescription xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy>
                        <xsl:variable name="newAuth">
                            <xsl:call-template name="newAuth"/>
                        </xsl:variable>
                        <xsl:if test="$newAuth!=''">
                            <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="normalize-space(.)"/>
                    </xsl:copy>
                </physicalDescription>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="extent">
        <xsl:for-each select="mods:extent">
            <xsl:copy>
                <xsl:variable name="newAuth">
                    <xsl:call-template name="newAuth"/>
                </xsl:variable>
                <xsl:if test="$newAuth!=''">
                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                </xsl:if>
                <xsl:value-of select="normalize-space(.)"/>
            </xsl:copy>
        </xsl:for-each>
        <xsl:for-each select="../mods:extent">
            <xsl:copy>
                <xsl:variable name="newAuth">
                    <xsl:call-template name="newAuth"/>
                </xsl:variable>
                <xsl:if test="$newAuth!=''">
                    <xsl:attribute name="authority"><xsl:value-of select="normalize-space($newAuth)"/></xsl:attribute>
                </xsl:if>
                <xsl:copy-of select="@* | * | text()"/>
            </xsl:copy>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="mods:internetMediaType"/>
    
    <xsl:template match="mods:relatedItem">
        <xsl:for-each select="mods:name">
            <xsl:choose>
                <xsl:when test="mods:namePart">
                    <name xmlns="http://www.loc.gov/mods/v3">
                        <xsl:copy-of select="@* | * | text()"/>
                    </name>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="mods:abstract">
            <note xmlns="http://www.loc.gov/mods/v3">
                <xsl:copy-of select="@* | * | text()"/>
            </note>
        </xsl:for-each>
        <xsl:for-each select="mods:note">
            <note xmlns="http://www.loc.gov/mods/v3">
                <xsl:copy-of select="@* | * | text()"/>
            </note>
        </xsl:for-each>
        <xsl:copy>
            <xsl:attribute name="type">
                <xsl:choose>
                    <xsl:when test="@type='preceeding'"><xsl:text>preceding</xsl:text></xsl:when>
                    <xsl:when test="not(@type)"><xsl:text>host</xsl:text></xsl:when>
                    <xsl:otherwise><xsl:value-of select="normalize-space(@type)"/></xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>
            <xsl:for-each select="mods:titleInfo[not(@type)]">
                <titleInfo xmlns="http://www.loc.gov/mods/v3">
                    <xsl:choose>
                        <xsl:when test="not(mods:title)">
                            <title><xsl:value-of select="normalize-space(.)"/></title>
                        </xsl:when>
                        <xsl:otherwise>
                            <title>
                                <xsl:if test="mods:nonSort"><xsl:value-of select="normalize-space(mods:nonSort)"/><xsl:text> </xsl:text></xsl:if>
                                <xsl:value-of select="normalize-space(mods:title)"/>
                                <xsl:if test="mods:subTitle"><xsl:text>: </xsl:text><xsl:value-of select="normalize-space(mods:subTitle)"/></xsl:if>
                            </title>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="mods:partNumber">
                        <partNumber><xsl:value-of select="normalize-space(mods:partNumber)"/></partNumber>
                    </xsl:if>
                </titleInfo>
            </xsl:for-each>
            <xsl:for-each select="mods:titleInfo[@type='abbreviated']">
                <xsl:choose>
                    <xsl:when test="../mods:titleInfo[not(@type)]"/>
                    <xsl:otherwise>
                        <titleInfo>
                            <title><xsl:value-of select="normalize-space(.)"/></title>
                        </titleInfo>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
            <xsl:for-each select="mods:identifier">
                <xsl:choose>
                    <xsl:when test="lower-case(@type)='pid'"/>
                    <xsl:when test="@type!=''"><identifier xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(@type)"/><xsl:text>: </xsl:text><xsl:value-of select="normalize-space(.)"/></identifier></xsl:when>
                </xsl:choose>
            </xsl:for-each>
            <xsl:for-each select="mods:genre">
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:for-each>
            <xsl:for-each select="mods:part">
                <xsl:copy>
                    <xsl:call-template name="partDetail"/>
                <xsl:for-each select="mods:extent">
                    <xsl:copy>
                        <xsl:copy-of select="@* | * | text()"/>
                    </xsl:copy>
                </xsl:for-each>
                </xsl:copy>
            </xsl:for-each>
            <xsl:for-each select="mods:physicalDescription">
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="mods:physicalLocation">
        <xsl:choose>
            <xsl:when test="parent::mods:location">
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <location xmlns="http://www.loc.gov/mods/v3">
                    <physicalLocation><xsl:value-of select="normalize-space(.)"/></physicalLocation>
                </location>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:shelfLocator">
        <xsl:choose>
            <xsl:when test="parent::mods:location">
                <holdingSimple xmlns="http://www.loc.gov/mods/v3">
                    <copyInformation>
                        <shelfLocator><xsl:value-of select="normalize-space(.)"/></shelfLocator>
                    </copyInformation>
                </holdingSimple>
            </xsl:when>
            <xsl:when test="parent::mods:copyInformation">
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <location xmlns="http://www.loc.gov/mods/v3">
                    <holdingSimple xmlns="http://www.loc.gov/mods/v3">
                        <copyInformation>
                            <shelfLocator><xsl:value-of select="normalize-space(.)"/></shelfLocator>
                        </copyInformation>
                    </holdingSimple>
                </location>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:note_accessCondition_use_and_reproduction">
        <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
    </xsl:template>
    
    <xsl:template match="mods:accessCondition_abstract">
        <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
    </xsl:template>
    
    <xsl:template match="mods:accessCondition">
        <xsl:choose>
            <xsl:when test="starts-with(lower-case(@displayLabel), 'creative')">
                <xsl:choose>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/licenses/by-nc-nd/2.0/','http://creativecommons.org/licenses/by-nc-nd/2.5/br/','http://creativecommons.org/licenses/by-nc-nd/2.5/ca/','http://creativecommons.org/licenses/by-nc-nd/3.0/','http://creativecommons.org/licenses/by-nc-nd/4.0/','https://creativecommons.org/licenses/by-nc-nd/2.5/ca/','https://creativecommons.org/licenses/by-nc-nd/4.0/')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Attribution-NonCommercial-NoDerivatives 4.0 International (CC BY-NC-ND 4.0)</accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/licenses/by-nc-sa/2.5/ca/','http://creativecommons.org/licenses/by-nc-sa/4.0/')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)</accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/licenses/by-nc/2.5/ca/','http://creativecommons.org/licenses/by-nc/2.5/pt/','http://creativecommons.org/licenses/by-nc/3.0/','http://creativecommons.org/licenses/by-nc/4.0/')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)</accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/licenses/by-nd/2.0/ca/','http://creativecommons.org/licenses/by-nd/2.5/ca/','http://creativecommons.org/licenses/by-nd/4.0/')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Attribution-NoDerivatives 4.0 International (CC BY-ND 4.0)</accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/licenses/by-sa/2.0/','http://creativecommons.org/licenses/by-sa/2.5/ca/','http://creativecommons.org/licenses/by-sa/4.0/','https://creativecommons.org/licenses/by-sa/2.0/','https://creativecommons.org/licenses/by-sa/2.0/ca/')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)</accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/licenses/by/2.0/','http://creativecommons.org/licenses/by/2.5/ca/','http://creativecommons.org/licenses/by/3.0/','http://creativecommons.org/licenses/by/4.0/')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Attribution 4.0 International (CC BY 4.0)</accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/publicdomain/mark/1.0/',' http://creativecommons.org/publicdomain/mark/1.0')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Public Domain Mark 1.0 Universal</accessCondition>
                    </xsl:when>
                    <xsl:when test="lower-case(.)=('http://creativecommons.org/publicdomain/zero/1.0/')">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">CC0 1.0 Universal</accessCondition>
                    </xsl:when>
                    <xsl:otherwise>
                        <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
                    </xsl:otherwise>
                </xsl:choose>               
            </xsl:when>
            <xsl:when test="@type='useAndReproduction'">
                <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
            </xsl:when>
            <xsl:when test="@type='restriction on access'">
                <xsl:choose>
                    <xsl:when test="starts-with(lower-case(@displayLabel), 'rights statement')">
                        <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT - NON-COMMERCIAL USE PERMITTED</accessCondition>
                    </xsl:when>
                    <xsl:otherwise>
                        <accessCondition type="restriction on access" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="@type='use and reproduction'">
                <xsl:choose>
                    <xsl:when test="lower-case(@displayLabel)=('copyright','restricted','software licence')">
                        <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
                    </xsl:when>
                    <xsl:when test="starts-with(lower-case(@displayLabel), 'rights ')">
                        <xsl:choose>
                            <xsl:when test=".=('http://rightsssatements.org/vocab/CNE/1.0/','http://rightsstatements.org/vocab/CNE/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">COPYRIGHT NOT EVALUATED</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/InC-EDU/1.0/','http://rightsstatements.org/vocab/inC-EDU/1.0/','https://rightsstatements.org/page/InC-EDU/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT - EDUCATIONAL USE PERMITTED</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/InC-NC/1.0/','IN COPYRIGHT - NON-COMMERCIAL USE PERMITTED')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT - NON-COMMERCIAL USE PERMITTED</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/InC-RUU/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT - RIGHTS-HOLDER(S) UNLOCATABLE OR UNIDENTIFIABLE</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/InC/1.0/','http://rightsstatements.org/vocab/InC/1.1/','http://rightsstatements.org/vocab/InC/1.2/','http://rightsstatements.org/vocab/InC/1.3/','https://rightsstatements.org/page/InC/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/NKC/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">NO KNOWN COPYRIGHT</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/NoC-NC/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">NO COPYRIGHT - NON-COMMERCIAL USE ONLY</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/NoC-OKLR/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">NO COPYRIGHT - OTHER KNOWN LEGAL RESTRICTIONS</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/NoC-US/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">NO COPYRIGHT - UNITED STATES</accessCondition>
                            </xsl:when>
                            <xsl:when test=".=('http://rightsstatements.org/vocab/UND/1.0/')">
                                <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">COPYRIGHT UNDETERMINED</accessCondition>
                            </xsl:when>
                            <xsl:otherwise>
                                <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:when test=".='http://creativecommons.org/licenses/by-nc-sa/4.0/'">
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)</accessCondition>
                    </xsl:when>
                    <xsl:when test=".='https://rightsstatements.org/page/InC-EDU/1.0/?language=en'">
                        <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT - EDUCATIONAL USE PERMITTED</accessCondition>
                    </xsl:when>
                    <xsl:when test=".='http://rightsstatements.org/vocab/InC-RUU/1.0/'">
                        <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT - RIGHTS-HOLDER(S) UNLOCATABLE OR UNIDENTIFIABLE</accessCondition>
                    </xsl:when>
                    <xsl:when test=".='http://rightsstatements.org/vocab/InC/1.0/'">
                        <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">IN COPYRIGHT</accessCondition>
                    </xsl:when>
                    <xsl:when test=".='NO KNOWN COPYRIGHT + Public Domain Mark 1.0 Universal'">
                        <accessCondition type="use and reproduction" displayLabel="rights statement" xmlns="http://www.loc.gov/mods/v3">NO KNOWN COPYRIGHT</accessCondition>
                        <accessCondition type="use and reproduction" displayLabel="Creative Commons license" xmlns="http://www.loc.gov/mods/v3">Public Domain Mark 1.0 Universal</accessCondition>
                    </xsl:when>
                    <xsl:otherwise>
                        <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <accessCondition type="use and reproduction" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></accessCondition>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>   
    
    <xsl:template match="mods:part">
        <xsl:choose>
            <xsl:when test="parent::mods:relatedItem">
                <xsl:copy>
                    <xsl:if test="mods:detail!=''">
                        <xsl:call-template name="partDetail"/>
                    </xsl:if>
                    <xsl:for-each select="mods:extent">
                        <xsl:copy>
                            <xsl:copy-of select="@* | * | text()"/>
                        </xsl:copy>
                    </xsl:for-each>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="mods:detail[not(@type)]">
                <relatedItem type="host" xmlns="http://www.loc.gov/mods/v3">
                    <part>
                <detail type="issue"><xsl:value-of select="normalize-space(.)"/></detail>
                    <xsl:for-each select="mods:extent">
                        <xsl:copy>
                            <xsl:copy-of select="@* | * | text()"/>
                        </xsl:copy>
                    </xsl:for-each>
                    </part>
                </relatedItem>
            </xsl:when>
            <xsl:when test="mods:detail[@type='page']">
                <relatedItem type="host" xmlns="http://www.loc.gov/mods/v3">
                    <part>
                    <xsl:call-template name="partDetail"/>
                    <extent unit="page">
                        <start><xsl:value-of select="normalize-space(mods:detail[@type='page'])"/></start>
                    </extent>
                    </part>
                </relatedItem>
            </xsl:when>
            <xsl:otherwise>
                <relatedItem type="host" xmlns="http://www.loc.gov/mods/v3">
                    <xsl:call-template name="partDetail"/>
                    <xsl:for-each select="mods:extent">
                        <xsl:copy>
                            <xsl:copy-of select="@* | * | text()"/>
                        </xsl:copy>
                    </xsl:for-each>
                </relatedItem>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mods:detail">
        <xsl:choose>
            <xsl:when test="not(parent::mods:part)"/>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@* | * | text()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="partDetail">
        <xsl:if test="mods:detail!=''">
            <xsl:variable name="volNo"><xsl:value-of select="normalize-space(mods:detail[@type='volume'])"/></xsl:variable>
            <xsl:variable name="issNo"><xsl:value-of select="normalize-space(mods:detail[@type='issue'])"/></xsl:variable>
            <detail type="issue" xmlns="http://www.loc.gov/mods/v3">
                <xsl:if test="$volNo!='' and $issNo!=''">
                    <xsl:text>Volume </xsl:text><xsl:value-of select="normalize-space($volNo)"/><xsl:text>, Issue </xsl:text><xsl:value-of select="normalize-space($issNo)"/>  
                </xsl:if>
                <xsl:if test="$volNo!='' and $issNo=''">
                    <xsl:text>Volume </xsl:text><xsl:value-of select="normalize-space($volNo)"/>  
                </xsl:if>
                <xsl:if test="$volNo='' and $issNo!=''">
                    <xsl:text>Issue </xsl:text><xsl:value-of select="normalize-space($issNo)"/>  
                </xsl:if>
            </detail>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="mods:recordInfo">
        <xsl:copy>
            <xsl:for-each select="mods:recordContentSource">
                <recordContentSource xmlns="http://www.loc.gov/mods/v3">
                    <xsl:value-of select="normalize-space(.)"/>
                </recordContentSource>
            </xsl:for-each>
            <xsl:for-each select="mods:recordCreationDate">
                <xsl:variable name="element-name" select="local-name()"/>
                <xsl:element name="{$element-name}" xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy-of select="@point"/>
                    <xsl:variable name="newDate">
                        <xsl:call-template name="format-dates">
                            <xsl:with-param name="date-value" select="normalize-space(.)"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:call-template name="qualifier">
                        <xsl:with-param name="qual-date" select="normalize-space($newDate)"/>
                    </xsl:call-template>
                </xsl:element>
            </xsl:for-each>
            <xsl:for-each select="../mods:originInfo/mods:dateCreated">
                <xsl:if test="../mods:dateIssued">
                    <recordCreationDate xmlns="http://www.loc.gov/mods/v3">
                        <xsl:copy-of select="@point"/>
                        <xsl:variable name="newDate">
                            <xsl:call-template name="format-dates">
                                <xsl:with-param name="date-value" select="normalize-space(.)"/>
                            </xsl:call-template>
                        </xsl:variable>
                        <xsl:call-template name="qualifier">
                            <xsl:with-param name="qual-date" select="normalize-space($newDate)"/>
                        </xsl:call-template>
                    </recordCreationDate>
                </xsl:if>
            </xsl:for-each>
            <xsl:for-each select="mods:recordChangeDate">
                <xsl:variable name="element-name" select="local-name()"/>
                <xsl:element name="{$element-name}" xmlns="http://www.loc.gov/mods/v3">
                    <xsl:copy-of select="@point"/>
                    <xsl:variable name="newDate">
                        <xsl:call-template name="format-dates">
                            <xsl:with-param name="date-value" select="normalize-space(.)"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:call-template name="qualifier">
                        <xsl:with-param name="qual-date" select="normalize-space($newDate)"/>
                    </xsl:call-template>
                </xsl:element>
            </xsl:for-each>
            <xsl:for-each select="mods:recordIdentifier">
                <recordIdentifier xmlns="http://www.loc.gov/mods/v3">
                    <xsl:value-of select="normalize-space(.)"/>
                </recordIdentifier>
            </xsl:for-each>
            <xsl:for-each select="mods:recordOrigin">
                <recordOrigin xmlns="http://www.loc.gov/mods/v3">
                    <xsl:value-of select="normalize-space(.)"/>
                </recordOrigin>
            </xsl:for-each>
            <xsl:for-each select="mods:recordInfoNote">
                <recordInfoNote xmlns="http://www.loc.gov/mods/v3">
                    <xsl:if test="@displayLabel!=''"><xsl:value-of select="normalize-space(@displayLabel)"/><xsl:text>: </xsl:text></xsl:if>
                    <xsl:value-of select="normalize-space(.)"/>
                </recordInfoNote>
            </xsl:for-each>
            <xsl:for-each select="mods:languageOfCataloging">
                <languageOfCataloging xmlns="http://www.loc.gov/mods/v3">
                    <languageTerm type="text">
                        <xsl:call-template name="langToText"/>
                    </languageTerm>
                </languageOfCataloging>
            </xsl:for-each>
            <xsl:for-each select="mods:descriptionStandard">
                <descriptionStandard xmlns="http://www.loc.gov/mods/v3">
                    <xsl:value-of select="normalize-space(.)"/>
                </descriptionStandard>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>



    <xsl:template name="nameParts">
        <xsl:if test="mods:namePart[not(@type)]">
            <xsl:choose>
                <xsl:when test="mods:namePart[not(@type)][2]">
                    <namePart xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(mods:namePart[not(@type)][1])"/><xsl:text>. </xsl:text><xsl:value-of select="normalize-space(mods:namePart[not(@type)][2])"/></namePart>
                </xsl:when>
                <xsl:otherwise>
                    <namePart xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(mods:namePart[not(@type)])"/></namePart>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
        <xsl:for-each select="mods:namePart[@type='family']">
            <xsl:choose>
                <xsl:when test="not(../mods:namePart[@type='given'])">
                    <namePart xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></namePart>
                </xsl:when>
                <xsl:otherwise>
                    <namePart type="family" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></namePart>
                </xsl:otherwise>
                </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="mods:namePart[@type='given']">
            <xsl:choose>
                <xsl:when test="not(../mods:namePart[@type='family'])">
                    <namePart xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></namePart>
                </xsl:when>
                <xsl:otherwise>
                    <namePart type="given" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></namePart>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="mods:namePart[@type='date']"><namePart type="date" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></namePart></xsl:for-each>
        <xsl:for-each select="mods:namePart[@type='culture']"><namePart type="culture" xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></namePart></xsl:for-each>
        <xsl:for-each select="mods:affiliation"><affiliation xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></affiliation></xsl:for-each>
        <xsl:for-each select="mods:alternativeName"><alternativeName xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></alternativeName></xsl:for-each>
        <xsl:for-each select="mods:description"><description xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></description></xsl:for-each>
        <xsl:for-each select="mods:nameIdentifier">
            <xsl:choose>
                <xsl:when test="starts-with(.,'https://orcid.org/')">
                    <nameIdentifier type='orcid' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></nameIdentifier>
                </xsl:when>
                <xsl:when test="@type='orcid'">
                    <nameIdentifier type='orcid' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></nameIdentifier>
                </xsl:when>
                <xsl:when test="@type='email'">
                    <nameIdentifier type='email' xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></nameIdentifier>
                </xsl:when>
                <xsl:otherwise><nameIdentifier xmlns="http://www.loc.gov/mods/v3"><xsl:value-of select="normalize-space(.)"/></nameIdentifier></xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="creatorRole">
        <xsl:choose>
            <xsl:when test="mods:role[not(mods:roleTerm)]">
                <role xmlns="http://www.loc.gov/mods/v3">
                    <roleTerm><xsl:value-of select="normalize-space(mods:role)"/></roleTerm>
                </role>
            </xsl:when>
            <xsl:when test="mods:role/mods:roleTerm">
                <role xmlns="http://www.loc.gov/mods/v3">
                    <xsl:for-each select="mods:role/mods:roleTerm[@type='code']">
                        <xsl:choose>
                            <xsl:when test="../mods:roleTerm[@type='text']"/>
                            <xsl:otherwise>
                                <xsl:variable name="cleanRole">
                                    <xsl:call-template name="cleanRole"/>
                                </xsl:variable>
                                <roleTerm><xsl:value-of select="normalize-space($cleanRole)"/></roleTerm>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                    <xsl:for-each select="mods:role/mods:roleTerm[@type='text']">
                        <xsl:variable name="cleanRole">
                            <xsl:call-template name="cleanRole"/>
                        </xsl:variable>
                        <roleTerm><xsl:value-of select="normalize-space($cleanRole)"/></roleTerm>
                    </xsl:for-each>
                    <xsl:for-each select="mods:role/mods:roleTerm[not(@type)]">
                        <xsl:variable name="cleanRole">
                            <xsl:call-template name="cleanRole"/>
                        </xsl:variable>
                        <roleTerm><xsl:value-of select="normalize-space($cleanRole)"/></roleTerm>
                    </xsl:for-each>
                </role>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="cleanRole">
        <xsl:choose>
            <xsl:when test="lower-case(.) = ('artisit','artist','artists','artists (visual artist)')">Artist</xsl:when>
            <xsl:when test="lower-case(.) = ('author')">Author</xsl:when>
            <xsl:when test="lower-case(.) = ('collaborator')">Contributor</xsl:when>
            <xsl:when test="lower-case(.) = ('collector')">Collector</xsl:when>
            <xsl:when test="lower-case(.) = ('committee member')">Degree Committee Member</xsl:when>
            <xsl:when test="lower-case(.) = ('compiler','complier')">Compiler</xsl:when>
            <xsl:when test="lower-case(.) = ('composer')">Composer</xsl:when>
            <xsl:when test="lower-case(.) = ('creator','crreator')">Creator</xsl:when>
            <xsl:when test="lower-case(.) = ('degree granting institution','degree grantor')">Degree granting institution</xsl:when>
            <xsl:when test="lower-case(.) = ('editior','editor','editor.')">Editor</xsl:when>
            <xsl:when test="lower-case(.) = ('expert')">Expert</xsl:when>
            <xsl:when test="lower-case(.) = ('funder')">Funder</xsl:when>
            <xsl:when test="lower-case(.) = ('illustrator.')">Illustrator</xsl:when>
            <xsl:when test="lower-case(.) = ('interview')">Interviewer</xsl:when>
            <xsl:when test="lower-case(.) = ('interviewee')">Interviewee</xsl:when>
            <xsl:when test="lower-case(.) = ('performer')">Performer</xsl:when>
            <xsl:when test="lower-case(.) = ('photogragher','photograher','photographer')">Photographer</xsl:when>
            <xsl:when test="lower-case(.) = ('presenter')">Presenter</xsl:when>
            <xsl:when test="lower-case(.) = ('producer')">Producer</xsl:when>
            <xsl:when test="lower-case(.) = ('production company')">Production company</xsl:when>
            <xsl:when test="lower-case(.) = ('production personnel')">Production personnel</xsl:when>
            <xsl:when test="lower-case(.) = ('speaker')">Speaker</xsl:when>
            <xsl:when test="lower-case(.) = ('thesis advisor')">Thesis advisor</xsl:when>
            <xsl:when test="lower-case(.) = ('translator')">Translator</xsl:when>
            <xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="newAuth">
        <xsl:choose>
            <xsl:when test="lower-case(@authority) = ('lcnaf')">naf</xsl:when>
            <xsl:when test="lower-case(@authority) = ('smd')">marcsmd</xsl:when>
            <xsl:otherwise><xsl:value-of select="normalize-space(@authority)"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="langToText">
        <xsl:choose>
            <xsl:when test="lower-case(normalize-space(.))=('eng','e','en','end','Englsih')">
                <xsl:text>English</xsl:text>
            </xsl:when>
            <xsl:when test="normalize-space(.)='Englsih'">
                <xsl:text>English</xsl:text>
            </xsl:when>
            <xsl:when test="lower-case(normalize-space(.))=('fre','fr')">
                <xsl:text>French</xsl:text>
            </xsl:when>
            <xsl:when test="lower-case(normalize-space(.))='chi'">
                <xsl:text>Chinese</xsl:text>
            </xsl:when>
            <xsl:when test="lower-case(normalize-space(.))='fin'">
                <xsl:text>Finnish</xsl:text>
            </xsl:when>
            <xsl:when test="lower-case(normalize-space(.))='zxx'">
                <xsl:text>No linguistic content</xsl:text>
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>