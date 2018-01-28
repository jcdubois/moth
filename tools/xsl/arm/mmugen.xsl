<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dyn="http://exslt.org/dynamic" xmlns:ext="http://exslt.org/common" version="1.0">
  <xsl:output method="text"/>

  <xsl:template match="/">
    <xsl:apply-templates select="platform/contexts"/>
  </xsl:template>

  <xsl:template match="contexts">
    <xsl:text>/*****************************************************************************&#xa;</xsl:text>
    <xsl:text> *&#xa;</xsl:text>
    <xsl:text> * Static ARM32 MMU table generated by mmugen&#xa;</xsl:text>
    <xsl:text> *&#xa;</xsl:text>
    <xsl:text> * Note: The generated table is compliant with the short-descriptor&#xa;</xsl:text>
    <xsl:text> *&#x9;translation table format of the "ARM Architecture Reference&#xa;</xsl:text>
    <xsl:text> *&#x9;Manual, ARMv7-A and ARMv7-R edition" (chapter B3.5) with&#xa;</xsl:text>
    <xsl:text> *&#x9;"AP[2:1] access permissions model" (chapter B3.7.1).&#xa;</xsl:text>
    <xsl:text> *&#x9;Memory is configured as non bufferable and non sharable.&#xa;</xsl:text>
    <xsl:text> *&#x9;For now there is only a single domain 0 configured.&#xa;</xsl:text>
    <xsl:text> *&#x9;It does not support the "Secure" state (trustzone) nor the&#xa;</xsl:text>
    <xsl:text> *&#x9;hypervisor (PL2) state.&#xa;</xsl:text>
    <xsl:text> *&#xa;</xsl:text>
    <xsl:text> *****************************************************************************/&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>#include &lt;arm_mmu.h&gt;&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>/*****************************************************************************&#xa;</xsl:text>
    <xsl:text> * Macros&#xa;</xsl:text>
    <xsl:text> *****************************************************************************/&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>#define DEFAULT_LVL1_ATTR (MM_LVL1_TABLE_NS + MM_LVL1_TABLE_PX + MM_LVL1_TABLE)&#xa;</xsl:text>
    <xsl:text>#define DEFAULT_LVL2_ATTR (MM_LVL2_NON_GLOBAL + MM_LVL2_NON_SHARABLE + MM_LVL2_NON_BUFFERABLE + MM_LVL2_SMALL)&#xa;</xsl:text>
    <xsl:text>#define CTX(paddr) ((uint32_t)paddr)&#xa;</xsl:text>
    <xsl:text>#define PTD(paddr) ((uint32_t)((paddr) + DEFAULT_LVL1_ATTR))&#xa;</xsl:text>
    <xsl:text>#define PTE(paddr, cache, prot) ((uint32_t)((paddr) + (cache) + (prot) + DEFAULT_LVL2_ATTR))&#xa;</xsl:text>
    <xsl:text>#define FAULT() 0&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>/*****************************************************************************&#xa;</xsl:text>
    <xsl:text> * Tables of the various contexts&#xa;</xsl:text>
    <xsl:text> * "One table for each context"&#xa;</xsl:text>
    <xsl:text> *****************************************************************************/&#xa;</xsl:text>
    <xsl:apply-templates select="context" mode="level1"/>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>/*****************************************************************************&#xa;</xsl:text>
    <xsl:text> * Main contexts table&#xa;</xsl:text>
    <xsl:text> * "One table to rule them all"&#xa;</xsl:text>
    <xsl:text> *****************************************************************************/&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>static uint32_t mmu_entry[CONFIG_MAX_TASK_COUNT]&#xa;</xsl:text>
    <xsl:text>&#x9;__attribute__ ((section(".mmutable"))) = {&#xa;</xsl:text>
    <xsl:apply-templates select="context" mode="level0"/>
    <xsl:text>};&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>/*****************************************************************************&#xa;</xsl:text>
    <xsl:text> * os_arch_mmu_table_init:&#xa;</xsl:text>
    <xsl:text> * This function needs to be called to reformat the PTD entries in memory&#xa;</xsl:text>
    <xsl:text> * before using them.&#xa;</xsl:text>
    <xsl:text> *****************************************************************************/&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>void os_arch_mmu_table_init(void)&#xa;</xsl:text>
    <xsl:text>{&#xa;</xsl:text>
    <xsl:text>}&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>uint32_t os_arch_mmu_get_ctx_table(void)&#xa;</xsl:text>
    <xsl:text>{&#xa;</xsl:text>
    <xsl:text>  return (uint32_t)mmu_entry;&#xa;</xsl:text>
    <xsl:text>}&#xa;</xsl:text>
  </xsl:template>

  <xsl:template match="context" mode="level0">
    <xsl:text>&#x9;CTX(</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>_level1),
</xsl:text>
  </xsl:template>

  <xsl:template match="context" mode="level1">
    <xsl:variable name="tmp">
      <xsl:apply-templates select="virtual_ref"/>
    </xsl:variable>
    <xsl:variable name="virtualMapping">
      <xsl:for-each select="ext:node-set($tmp)/virtual_page">
        <xsl:sort select="virt"/>
        <xsl:copy-of select="."/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>/*****************************************************************************&#xa;</xsl:text>
    <xsl:text> * table for "</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>" partition&#xa;</xsl:text>
    <xsl:text> *****************************************************************************/&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
    <xsl:call-template name="level2">
      <xsl:with-param name="pages" select="$virtualMapping"/>
      <xsl:with-param name="name" select="@name"/>
    </xsl:call-template>
    <xsl:text>static uint32_t </xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>_level1[MM_LVL1_ENTRIES_NBR]&#xa;</xsl:text>
    <xsl:text>&#x9;__attribute__ ((section(".mmutable")))&#xa;</xsl:text>
    <xsl:text>&#x9;__attribute__ ((aligned (MM_LVL1_ENTRIES_NBR * sizeof(uint32_t)))) = {&#xa; </xsl:text>
    <xsl:call-template name="level1">
      <xsl:with-param name="pages" select="$virtualMapping"/>
      <xsl:with-param name="name" select="@name"/>
    </xsl:call-template>
    <xsl:text>};&#xa;</xsl:text>
  </xsl:template>

  <xsl:template name="level2">
    <xsl:param name="pages"/>
    <xsl:param name="name"/>
    <xsl:if test="ext:node-set($pages)/virtual_page[1]">
      <xsl:variable name="vaddress" select="(ext:node-set($pages)/virtual_page[1]/virt div 1048576) * 1048576"/>
      <xsl:variable name="nextaddress" select="$vaddress + 1048576"/>
      <xsl:text>static uint32_t </xsl:text>
      <xsl:value-of select="@name"/>
      <xsl:text>_</xsl:text>
      <xsl:call-template name="toHex">
        <xsl:with-param name="num" select="$vaddress"/>
      </xsl:call-template>
      <xsl:text>_level2[MM_LVL2_ENTRIES_NBR]&#xa;</xsl:text>
      <xsl:text>&#x9;__attribute__ ((section(".mmutable")))&#xa;</xsl:text>
      <xsl:text>&#x9;__attribute__ ((aligned (MM_LVL2_ENTRIES_NBR * sizeof(uint32_t)))) = {&#xa;</xsl:text>
      <xsl:variable name="head">
        <xsl:for-each select="ext:node-set($pages)/virtual_page">
          <xsl:if test="$nextaddress > virt">
            <xsl:copy-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:call-template name="level23">
        <xsl:with-param name="pages" select="$head"/>
        <xsl:with-param name="name" select="$name"/>
        <xsl:with-param name="vaddress" select="$vaddress"/>
        <xsl:with-param name="endaddress" select="$nextaddress"/>
      </xsl:call-template>
      <xsl:text>};&#xa;</xsl:text>
      <xsl:text>&#xa;</xsl:text>
      <xsl:variable name="tail">
        <xsl:for-each select="ext:node-set($pages)/virtual_page">
          <xsl:if test="virt >=  $nextaddress">
            <xsl:copy-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:call-template name="level2">
        <xsl:with-param name="pages" select="$tail"/>
        <xsl:with-param name="name" select="$name"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template name="level23">
    <xsl:param name="pages"/>
    <xsl:param name="name"/>
    <xsl:param name="vaddress" select="0"/>
    <xsl:param name="endaddress" select="0"/>
    <xsl:if test="$endaddress > $vaddress">
      <xsl:variable name="nextaddress" select="$vaddress + 4096"/>
      <xsl:text>/* </xsl:text>
      <xsl:call-template name="toHex">
        <xsl:with-param name="num" select="$vaddress"/>
      </xsl:call-template>
      <xsl:text>:</xsl:text>
      <xsl:call-template name="toHex">
        <xsl:with-param name="num" select="$nextaddress - 1"/>
      </xsl:call-template>
      <xsl:text> */ </xsl:text>
      <xsl:choose>
        <xsl:when test="$nextaddress > ext:node-set($pages)/virtual_page[1]/virt">
          <xsl:choose>
            <xsl:when test="ext:node-set($pages)/virtual_page[1]/protection!='fault'">
              <xsl:text>PTE(</xsl:text>
              <xsl:call-template name="toHex">
                <xsl:with-param name="num" select="ext:node-set($pages)/virtual_page[1]/phys"/>
              </xsl:call-template>
              <xsl:text>, </xsl:text>
              <xsl:value-of select="ext:node-set($pages)/virtual_page[1]/cache"/>
              <xsl:text>, </xsl:text>
              <xsl:value-of select="ext:node-set($pages)/virtual_page[1]/protection"/>
              <xsl:text>),</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>FAULT(),</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text> /* </xsl:text>
          <xsl:value-of select="ext:node-set($pages)/virtual_page[1]/partition"/>
          <xsl:text>.</xsl:text>
          <xsl:value-of select="ext:node-set($pages)/virtual_page[1]/name"/>
          <xsl:text> */ </xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>FAULT(),</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>&#xa;</xsl:text>
      <xsl:variable name="tail">
        <xsl:for-each select="ext:node-set($pages)/virtual_page">
          <xsl:if test="virt >=  $nextaddress">
            <xsl:copy-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:call-template name="level23">
        <xsl:with-param name="pages" select="$tail"/>
        <xsl:with-param name="name" select="$name"/>
        <xsl:with-param name="vaddress" select="$nextaddress"/>
        <xsl:with-param name="endaddress" select="$endaddress"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template name="level1">
    <xsl:param name="pages"/>
    <xsl:param name="name"/>
    <xsl:param name="vaddress" select="0"/>
    <xsl:if test="4294967296 > $vaddress">
      <xsl:variable name="nextaddress" select="$vaddress + 1048576"/>
      <xsl:text>/* </xsl:text>
      <xsl:call-template name="toHex">
        <xsl:with-param name="num" select="$vaddress"/>
      </xsl:call-template>
      <xsl:text>:</xsl:text>
      <xsl:call-template name="toHex">
        <xsl:with-param name="num" select="$nextaddress - 1"/>
      </xsl:call-template>
      <xsl:text> */ </xsl:text>
      <xsl:choose>
        <xsl:when test="$nextaddress > ext:node-set($pages)/virtual_page[1]/virt">
          <xsl:text>PTD(</xsl:text>
          <xsl:value-of select="$name"/>
          <xsl:text>_</xsl:text>
          <xsl:call-template name="toHex">
            <xsl:with-param name="num" select="ext:node-set($pages)/virtual_page[1]/virt"/>
          </xsl:call-template>
          <xsl:text>_level2),</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>FAULT(),</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>&#xa;</xsl:text>
      <xsl:variable name="tail">
        <xsl:for-each select="ext:node-set($pages)/virtual_page">
          <xsl:if test="virt >=  $nextaddress">
            <xsl:copy-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:call-template name="level1">
        <xsl:with-param name="pages" select="$tail"/>
        <xsl:with-param name="name" select="$name"/>
        <xsl:with-param name="vaddress" select="$nextaddress"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="virtual_ref">
    <xsl:variable name="ref1" select="./text()"/>
    <xsl:apply-templates select="dyn:evaluate($ref1)" mode="entry"/>
  </xsl:template>

  <xsl:template match="virtual" mode="entry">
    <xsl:apply-templates select="virtual_map" mode="entry"/>
  </xsl:template>

  <xsl:template match="virtual" mode="name">
    <xsl:value-of select="@name"/>
  </xsl:template>

  <xsl:template match="virtual_map" mode="entry">
    <xsl:variable name="vaddress">
      <xsl:apply-templates select="." mode="vaddress"/>
    </xsl:variable>
    <xsl:variable name="size">
      <xsl:apply-templates select="." mode="size"/>
    </xsl:variable>
    <xsl:variable name="paddress">
      <xsl:apply-templates select="." mode="paddress"/>
    </xsl:variable>
    <xsl:variable name="protection">
      <xsl:apply-templates select="." mode="protection"/>
    </xsl:variable>
    <xsl:variable name="cache">
      <xsl:apply-templates select="." mode="cache"/>
    </xsl:variable>
    <xsl:variable name="name" select="@name"/>
    <xsl:variable name="partition">
      <xsl:apply-templates select=".." mode="name"/>
    </xsl:variable>
    <xsl:variable name="decsize">
      <xsl:call-template name="toDecimal">
        <xsl:with-param name="num" select="$size"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="decvaddress">
      <xsl:call-template name="toDecimal">
        <xsl:with-param name="num" select="$vaddress"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="decpaddress">
      <xsl:call-template name="toDecimal">
        <xsl:with-param name="num" select="$paddress"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:call-template name="virtualPage">
      <xsl:with-param name="vaddress" select="$decvaddress"/>
      <xsl:with-param name="paddress" select="$decpaddress"/>
      <xsl:with-param name="size" select="$decsize"/>
      <xsl:with-param name="protection" select="$protection"/>
      <xsl:with-param name="name" select="$name"/>
      <xsl:with-param name="partition" select="$partition"/>
      <xsl:with-param name="cache" select="$cache"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="virtualPage">
    <xsl:param name="vaddress"/>
    <xsl:param name="paddress"/>
    <xsl:param name="size"/>
    <xsl:param name="protection"/>
    <xsl:param name="name"/>
    <xsl:param name="cache"/>
    <xsl:param name="partition"/>
    <xsl:if test="$size > 0">
      <xsl:element name="virtual_page">
        <xsl:element name="virt">
          <xsl:value-of select="$vaddress"/>
        </xsl:element>
        <xsl:element name="phys">
          <xsl:value-of select="$paddress"/>
        </xsl:element>
        <xsl:element name="name">
          <xsl:value-of select="$name"/>
        </xsl:element>
        <xsl:element name="partition">
          <xsl:value-of select="$partition"/>
        </xsl:element>
        <xsl:element name="protection">
          <xsl:value-of select="$protection"/>
        </xsl:element>
        <xsl:element name="cache">
          <xsl:value-of select="$cache"/>
        </xsl:element>
      </xsl:element>
      <xsl:call-template name="virtualPage">
        <xsl:with-param name="vaddress" select="$vaddress + 4096"/>
        <xsl:with-param name="paddress" select="$paddress + 4096"/>
        <xsl:with-param name="size" select="$size - 4096"/>
        <xsl:with-param name="protection" select="$protection"/>
        <xsl:with-param name="name" select="$name"/>
        <xsl:with-param name="partition" select="$partition"/>
        <xsl:with-param name="cache" select="$cache"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="virtual_map" mode="cache">
    <xsl:choose>
      <xsl:when test="@cache = 'true'">
        <xsl:text>MM_LVL2_CACHEABLE</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>MM_LVL2_NOCACHE</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
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

  <xsl:template match="virtual_map" mode="protection">
    <xsl:variable name="protection">
      <xsl:choose>
        <xsl:when test="./protection">
          <xsl:text>U</xsl:text>
          <xsl:apply-templates select="./protection" mode="user"/>
          <xsl:text>_S</xsl:text>
          <xsl:apply-templates select="./protection" mode="supervisor"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>U_S</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$protection='U_S'">
        <xsl:text>fault</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='U_SX' or $protection='U_SXR'">
        <xsl:text>(MM_LVL2_AP_RO | MM_LVL2_AP_SUP_ACCESS | MM_LVL2_SMALL_X)</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='U_SR'">
        <xsl:text>(MM_LVL2_AP_RO | MM_LVL2_AP_SUP_ACCESS | MM_LVL2_SMALL_XN)</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='U_SXRW' or $protection='U_SXW'">
        <xsl:text>(MM_LVL2_AP_RW | MM_LVL2_AP_SUP_ACCESS | MM_LVL2_SMALL_X)</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='U_SRW'">
        <xsl:text>(MM_LVL2_AP_RW | MM_LVL2_AP_SUP_ACCESS | MM_LVL2_SMALL_XN)</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='UX_S' or $protection='UX_SX'">
        <xsl:text>(MM_LVL2_AP_RO | MM_LVL2_AP_USER_ACCESS | MM_LVL2_SMALL_X)</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='UR_S' or $protection='UR_SR'">
        <xsl:text>(MM_LVL2_AP_RO | MM_LVL2_AP_USER_ACCESS | MM_LVL2_SMALL_XN)</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='URW_S' or $protection='URW_SR' or $protection='URW_SRW' or $protection='URW_SW' or $protection='UW_S' or $protection='UW_SR' or $protection='UW_SRW'">
        <xsl:text>(MM_LVL2_AP_RW | MM_LVL2_AP_USER_ACCESS | MM_LVL2_SMALL_XN)</xsl:text>
      </xsl:when>
      <xsl:when test="$protection='UXRW_S' or $protection='UXRW_SR' or $protection='UXRW_SRW' or $protection='UXRW_SXRW' or $protection='UXRW_SW' or $protection='UXRW_SXW' or $protection='UXRW_SXR'">
        <xsl:text>(MM_LVL2_AP_RW | MM_LVL2_AP_USER_ACCESS | MM_LVL2_SMALL_X)</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$protection"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="protection" mode="user">
    <xsl:apply-templates select="user">
      <xsl:sort select="@access"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="protection" mode="supervisor">
    <xsl:apply-templates select="supervisor">
      <xsl:sort select="@access"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="protection">
    <xsl:choose>
      <xsl:when test="./user">
        <xsl:text>user(</xsl:text>
        <xsl:apply-templates select="user"/>
        <xsl:text>)</xsl:text>
      </xsl:when>
      <xsl:when test="./supervisor">
        <xsl:text>supervisor(</xsl:text>
        <xsl:apply-templates select="supervisor"/>
        <xsl:text>)</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="user">
    <xsl:choose>
      <xsl:when test="@access = 'read'">
        <xsl:text>R</xsl:text>
      </xsl:when>
      <xsl:when test="@access = 'write'">
        <xsl:text>W</xsl:text>
      </xsl:when>
      <xsl:when test="@access = 'execute'">
        <xsl:text>X</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="supervisor">
    <xsl:choose>
      <xsl:when test="@access = 'read'">
        <xsl:text>R</xsl:text>
      </xsl:when>
      <xsl:when test="@access = 'write'">
        <xsl:text>W</xsl:text>
      </xsl:when>
      <xsl:when test="@access = 'execute'">
        <xsl:text>X</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="physical_map" mode="size">
    <xsl:choose>
      <xsl:when test="./size[1]">
        <xsl:value-of select="./size[1]"/>
      </xsl:when>
      <xsl:when test="./physical_map">
        <xsl:call-template name="sum_size">
          <xsl:with-param name="objects" select="./physical_map"/>
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
        <xsl:choose>
          <xsl:when test="$num > 0">
            <xsl:text>0x</xsl:text>
            <xsl:variable name="tmp">
              <xsl:call-template name="num2hex">
                <xsl:with-param name="dec" select="$num"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:value-of select="$tmp"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>0x00000000</xsl:text>
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
    <xsl:param name="total" select="0"/>
    <xsl:param name="objects"/>
    <xsl:variable name="head" select="$objects[1]"/>
    <xsl:variable name="tail" select="$objects[position()>1]"/>
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
        <xsl:value-of select="$total + $deccalc"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="sum_size">
          <xsl:with-param name="total" select="$total + $deccalc"/>
          <xsl:with-param name="objects" select="$tail"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="iterFault">
    <xsl:param name="num"/>
    <xsl:param name="index"/>
    <xsl:if test="$num > 0">
      <xsl:text>&#x9;FAULT(),&#x9;/* MMU entry #</xsl:text>
      <xsl:value-of select="$index"/>
      <xsl:text>*/&#xa;</xsl:text>
      <xsl:call-template name="iterFault">
        <xsl:with-param name="num" select="$num - 1"/>
        <xsl:with-param name="index" select="$index + 1"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
