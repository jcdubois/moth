﻿<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dyn="http://exslt.org/dynamic" xmlns:ext="http://exslt.org/common" version="1.0">
<xsl:output method="text"/>

<xsl:template match="/">
  <xsl:apply-templates select="platform/virtuals/virtual[@name != 'kernel']" mode="standalone"/>
  <xsl:apply-templates select="platform/virtuals" mode="combined"/>
</xsl:template>
  
<xsl:template match="virtuals" mode="combined">
  <xsl:text>/*****************************************************************************&#xa;</xsl:text>
  <xsl:text> *&#xa;</xsl:text>
  <xsl:text> * Moth linker script generated by linker.xsl&#xa;</xsl:text>
  <xsl:text> *&#xa;</xsl:text>
  <xsl:text> *****************************************************************************/&#xa;</xsl:text>
  <xsl:text>&#xa;</xsl:text>
  <xsl:text>OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")&#xa;</xsl:text>
  <xsl:text>OUTPUT_ARCH("arm")&#xa;</xsl:text>
  <xsl:text>ENTRY("entry")&#xa;</xsl:text>
  <xsl:text>&#xa;</xsl:text>
  <xsl:text>MEMORY&#xa;</xsl:text>
  <xsl:text>{&#xa;</xsl:text>
  <xsl:apply-templates select="virtual" mode="memory"/>
  <xsl:text>}&#xa;</xsl:text>
  <xsl:text>&#xa;</xsl:text>
  <xsl:text>SECTIONS /* Moth */&#xa;</xsl:text>
  <xsl:text>{&#xa;</xsl:text>
  <xsl:apply-templates select="virtual[@name = 'kernel']/virtual_map" mode="standalone"/>
  <xsl:apply-templates select="virtual[@name != 'kernel']/virtual_map" mode="application"/>
  <xsl:text>}&#xa;</xsl:text>
</xsl:template>

<xsl:template match="virtual" mode="standalone">
  <xsl:variable name="name" select="@name"/>
  <xsl:document href="{$name}.ld" method="text">
    <xsl:text>/*****************************************************************************&#xa;</xsl:text>
    <xsl:text> *&#xa;</xsl:text>
    <xsl:text> * Application linker script generated by linker.xsl&#xa;</xsl:text>
    <xsl:text> *&#xa;</xsl:text>
    <xsl:text> *****************************************************************************/&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")&#xa;</xsl:text>
    <xsl:text>OUTPUT_ARCH("arm")&#xa;</xsl:text>
    <xsl:text>ENTRY("entry")&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>MEMORY&#xa;</xsl:text>
    <xsl:text>{&#xa;</xsl:text>
    <xsl:apply-templates select="." mode="memory"/>
    <xsl:text>}&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>SECTIONS /* </xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text> */&#xa;</xsl:text>
    <xsl:text>{&#xa;</xsl:text>
    <xsl:apply-templates select="virtual_map" mode="standalone"/>
    <xsl:text>}&#xa;</xsl:text>
  </xsl:document>
</xsl:template>

<xsl:template match="virtual" mode="memory">
  <xsl:text>  </xsl:text>
  <xsl:value-of select="@name"/>
  <xsl:text> : ORIGIN = </xsl:text>
  <xsl:apply-templates select="." mode="vaddress"/>
  <xsl:text>, LENGTH = </xsl:text>
  <xsl:apply-templates select="." mode="vsize"/>
  <xsl:text>&#xa;</xsl:text>
</xsl:template>

<xsl:template match="virtual" mode="name">
  <xsl:value-of select="@name"/>
</xsl:template>

<xsl:template match="virtual" mode="vaddress">
  <xsl:apply-templates select="virtual_map[1]" mode="vaddress"/>
</xsl:template>

<xsl:template match="virtual" mode="vsize">
    <xsl:text>0x40000</xsl:text>
</xsl:template>

<xsl:template match="virtual_map" mode="standalone">
  <xsl:variable name="paddress">
    <xsl:apply-templates select="." mode="paddress"/>
  </xsl:variable>
  <xsl:variable name="decpaddress">
    <xsl:call-template name="toDecimal">
      <xsl:with-param name="num" select="$paddress"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:if test="$decpaddress > 0">
    <xsl:text>  .</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="." mode="vaddress"/>
    <xsl:text> : AT (</xsl:text>
    <xsl:apply-templates select="." mode="paddress"/>
    <xsl:text>)&#xa;</xsl:text>
    <xsl:text>  {&#xa;</xsl:text>
    <xsl:text>    __</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>_begin = .;&#xa;</xsl:text>
    <xsl:text>    *(.</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>.entry)&#xa;</xsl:text>
    <xsl:text>    *(.</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>*)&#xa;</xsl:text>
    <xsl:text>    __</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>_end = </xsl:text>
    <xsl:apply-templates select="." mode="size"/>
    <xsl:text>;&#xa;</xsl:text>
    <xsl:text>  } ></xsl:text>
    <xsl:value-of select="./../@name"/>
    <xsl:text> =00&#xa;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="virtual_map" mode="application">
  <xsl:variable name="paddress">
    <xsl:apply-templates select="." mode="paddress"/>
  </xsl:variable>
  <xsl:variable name="decpaddress">
    <xsl:call-template name="toDecimal">
      <xsl:with-param name="num" select="$paddress"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:if test="$decpaddress > 0">
    <xsl:text>  .</xsl:text>
    <xsl:value-of select="./../@name"/>
    <xsl:text>.</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="." mode="vaddress"/>
    <xsl:text> : AT (</xsl:text>
    <xsl:apply-templates select="." mode="paddress"/>
    <xsl:text>)&#xa;</xsl:text>
    <xsl:text>  {&#xa;</xsl:text>
    <xsl:text>    __</xsl:text>
    <xsl:value-of select="./../@name"/>
    <xsl:text>_</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>_begin = .;&#xa;</xsl:text>
    <xsl:text>    *(.</xsl:text>
    <xsl:value-of select="./../@name"/>
    <xsl:text>.</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>*)&#xa;</xsl:text>
    <xsl:text>    __</xsl:text>
    <xsl:value-of select="./../@name"/>
    <xsl:text>_</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>_end = </xsl:text>
    <xsl:apply-templates select="." mode="size"/>
    <xsl:text>;&#xa;</xsl:text>
    <xsl:text>  } ></xsl:text>
    <xsl:value-of select="./../@name"/>
    <xsl:text> =00&#xa;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="virtual_map" mode="vaddress">
  <xsl:choose>
    <xsl:when test="./address">
      <xsl:value-of select="./address"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="hexaddress">
        <xsl:apply-templates select="preceding-sibling::virtual_map[ 1] " mode="vaddress"/>
      </xsl:variable>
      <xsl:variable name="hexsize">
        <xsl:apply-templates select="preceding-sibling::virtual_map[ 1] " mode="size"/>
      </xsl:variable>
      <xsl:variable name="decaddress">
        <xsl:call-template name="toDecimal">
          <xsl:with-param name="num" select="$hexaddress"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="decsize">
        <xsl:call-template name="toDecimal">
          <xsl:with-param name="num" select="$hexsize"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:call-template name="toHex">
        <xsl:with-param name="num" select="$decsize + $decaddress"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="virtual_map" mode="size">
  <xsl:variable name="size">
  <xsl:choose>
    <xsl:when test="./size">
      <xsl:value-of select="./size"/>
    </xsl:when>
    <xsl:when test="./physical_ref">
      <xsl:variable name="ref1" select="./physical_ref/text()"/>
      <xsl:apply-templates select="dyn:evaluate($ref1)" mode="size"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>0</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:variable>
  <xsl:variable name="decsize">
    <xsl:call-template name="toDecimal">
      <xsl:with-param name="num" select="$size"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:call-template name="toHex">
    <xsl:with-param name="num" select="$decsize"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="virtual_map" mode="paddress">
  <xsl:choose>
    <xsl:when test="./physical_ref">
      <xsl:variable name="ref1" select="./physical_ref/text()"/>
      <xsl:apply-templates select="dyn:evaluate($ref1)" mode="paddress"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>0</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="physical_map" mode="size">
  <xsl:choose>
    <xsl:when test="./size[1]">
      <xsl:value-of select="./size[1]"/>
    </xsl:when>
    <xsl:when test="./physical_map">
      <xsl:call-template name="sum_size">
        <xsl:with-param name="objects" select="./physical_map" />
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>0</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="physical_map" mode="paddress">
  <xsl:choose>
    <xsl:when test="address">
      <xsl:value-of select="address"/>
    </xsl:when>
    <xsl:when test="preceding-sibling::physical_map[ 1]">
      <xsl:variable name="hexaddress">
        <xsl:apply-templates select="preceding-sibling::physical_map[ 1] " mode="paddress"/>
      </xsl:variable>
      <xsl:variable name="hexsize">
        <xsl:apply-templates select="preceding-sibling::physical_map[ 1] " mode="size"/>
      </xsl:variable>
      <xsl:variable name="decaddress">
        <xsl:call-template name="toDecimal">
          <xsl:with-param name="num" select="$hexaddress"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="decsize">
        <xsl:call-template name="toDecimal">
         <xsl:with-param name="num" select="$hexsize"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:call-template name="toHex">
        <xsl:with-param name="num" select="$decaddress + $decsize"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="ancestor::physical_map[ 1]">
      <xsl:apply-templates select=".." mode="paddress"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>0</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Utility functions -->

<xsl:template name="toHex">
  <xsl:param name="num"/>
  <xsl:choose>
    <xsl:when test="substring($num,2,1) = 'x'">
      <xsl:value-of select="$num"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>0x</xsl:text>
      <xsl:choose>
        <xsl:when test="$num > 0">
          <xsl:call-template name="num2hex">
            <xsl:with-param name="dec" select="$num"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>00000000</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="num2hex">
  <xsl:param name="dec"/>
  <xsl:if test="$dec > 0">
    <xsl:call-template name="num2hex">
      <xsl:with-param name="dec" select="floor($dec div 16)"/>
    </xsl:call-template>
    <xsl:value-of select="substring('0123456789ABCDEF', (($dec mod 16) + 1), 1)"/>
  </xsl:if>
</xsl:template>

<xsl:template name="toDecimal">
  <xsl:param name="num"/>
  <xsl:choose>
  <xsl:when test="substring($num,2,1) = 'x'">
    <xsl:call-template name="hex2num">
      <xsl:with-param name="hex">
        <xsl:value-of select="substring($num,3)"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:when>
  <xsl:otherwise>
    <xsl:value-of select="$num"/>
  </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="hex2num">
  <xsl:param name="hex"/>
  <xsl:param name="num" select="0"/>
  <xsl:param name="MSB" select="translate(substring($hex, 1, 1), 'abcdef', 'ABCDEF')"/>
  <xsl:param name="value" select="string-length(substring-before('0123456789ABCDEF', $MSB))"/>
  <xsl:param name="result" select="16 * $num + $value"/>
  <xsl:choose>
    <xsl:when test="string-length($hex) > 1">
      <xsl:call-template name="hex2num">
        <xsl:with-param name="hex" select="substring($hex, 2)"/>
        <xsl:with-param name="num" select="$result"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$result"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="sum_size">
  <xsl:param name="total" select="0" />
  <xsl:param name="objects"  />
  <xsl:variable name="head" select="$objects[1]" />
  <xsl:variable name="tail" select="$objects[position()>1]" />
  <xsl:variable name="calc">
    <xsl:apply-templates select="$head" mode="size"/>
  </xsl:variable> 
  <xsl:variable name="deccalc">
    <xsl:call-template name="toDecimal">
      <xsl:with-param name="num" select="$calc"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="not($tail)">
      <xsl:value-of select="$total + $deccalc" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="sum_size">
        <xsl:with-param name="total" select="$total + $deccalc" />
        <xsl:with-param name="objects" select="$tail" />
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
   
</xsl:stylesheet>