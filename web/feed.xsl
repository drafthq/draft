<?xml version="1.0" encoding="UTF-8"?>
<!--
  Browser stylesheet for feed.xml. RSS readers ignore the xml-stylesheet
  processing instruction and parse the raw RSS; web browsers apply this
  transform so the feed URL renders as a readable page instead of raw XML.
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:atom="http://www.w3.org/2005/Atom">
  <xsl:output method="html" encoding="UTF-8" doctype-system="about:legacy-compat"/>
  <xsl:template match="/rss/channel">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title><xsl:value-of select="title"/> — RSS Feed</title>
        <style>
          :root { color-scheme: dark; }
          * { box-sizing: border-box; }
          body {
            margin: 0; padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: #0a0d12; color: #e6e9ef; line-height: 1.6;
          }
          .wrap { max-width: 760px; margin: 0 auto; padding: 48px 24px 80px; }
          .banner {
            background: rgba(56, 189, 248, 0.08);
            border: 1px solid rgba(56, 189, 248, 0.25);
            border-radius: 12px; padding: 16px 20px; margin-bottom: 40px;
            font-size: 0.94rem; color: #bcd4e6;
          }
          .banner strong { color: #7dd3fc; }
          .banner a { color: #7dd3fc; }
          h1 { font-size: 2rem; margin: 0 0 8px; letter-spacing: -0.02em; }
          .home { color: #38bdf8; text-decoration: none; font-size: 0.9rem; }
          .home:hover { text-decoration: underline; }
          .desc { color: #9aa4b2; margin: 0 0 36px; }
          .item {
            padding: 22px 0; border-top: 1px solid rgba(255,255,255,0.08);
          }
          .item h2 { font-size: 1.2rem; margin: 0 0 6px; line-height: 1.35; }
          .item h2 a { color: #f1f5f9; text-decoration: none; }
          .item h2 a:hover { color: #7dd3fc; }
          .meta { font-size: 0.8rem; color: #64748b; margin: 0 0 10px; text-transform: uppercase; letter-spacing: 0.04em; }
          .meta .cat { color: #38bdf8; }
          .item p.summary { margin: 0; color: #c4ccd6; }
          footer { margin-top: 48px; font-size: 0.85rem; color: #64748b; }
          footer a { color: #38bdf8; text-decoration: none; }
        </style>
      </head>
      <body>
        <div class="wrap">
          <div class="banner">
            <strong>This is an RSS feed.</strong> Copy this page's URL into your feed reader to
            subscribe to new posts. Visit the <a href="https://getdraft.dev/blog/">blog</a> to read in your browser.
          </div>
          <a class="home" href="https://getdraft.dev/">&#8592; getdraft.dev</a>
          <h1><xsl:value-of select="title"/></h1>
          <p class="desc"><xsl:value-of select="description"/></p>
          <xsl:for-each select="item">
            <div class="item">
              <h2><a href="{link}"><xsl:value-of select="title"/></a></h2>
              <p class="meta">
                <xsl:value-of select="pubDate"/>
                <xsl:if test="category"> &#183; <span class="cat"><xsl:value-of select="category"/></span></xsl:if>
              </p>
              <p class="summary"><xsl:value-of select="description"/></p>
            </div>
          </xsl:for-each>
          <footer>
            Powered by Draft &#183; <a href="https://github.com/drafthq/draft">github.com/drafthq/draft</a>
          </footer>
        </div>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
