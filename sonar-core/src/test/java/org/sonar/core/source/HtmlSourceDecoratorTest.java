/*
 * Sonar, open source software quality management tool.
 * Copyright (C) 2008-2012 SonarSource
 * mailto:contact AT sonarsource DOT com
 *
 * Sonar is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * Sonar is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with Sonar; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02
 */

package org.sonar.core.source;

import org.junit.Before;
import org.junit.Test;
import org.sonar.core.persistence.AbstractDaoTestCase;
import org.sonar.core.source.jdbc.SnapshotDataDao;
import org.sonar.core.source.jdbc.SnapshotSourceDao;

import java.util.List;

import static org.fest.assertions.Assertions.assertThat;
import static org.mockito.Mockito.*;

public class HtmlSourceDecoratorTest extends AbstractDaoTestCase {

  @Before
  public void setUpDatasets() {
    setupData("shared");
  }

  @Test
  public void should_highlight_syntax_with_html() throws Exception {

    HtmlSourceDecorator sourceDecorator = new HtmlSourceDecorator(getMyBatis());

    List<String> decoratedSource = (List<String>) sourceDecorator.getDecoratedSourceAsHtml(11L);

    assertThat(decoratedSource).containsExactly(
      "<span class=\"cppd\">/*</span>",
      "<span class=\"cppd\"> * Header</span>",
      "<span class=\"cppd\"> */</span>",
      "",
      "<span class=\"k\">public </span><span class=\"k\">class </span>HelloWorld {",
      "}"
    );
  }

  @Test
  public void should_mark_symbols_with_html() throws Exception {

    HtmlSourceDecorator sourceDecorator = new HtmlSourceDecorator(getMyBatis());

    List<String> decoratedSource = (List<String>) sourceDecorator.getDecoratedSourceAsHtml(12L);

    assertThat(decoratedSource).containsExactly(
      "/*",
      " * Header",
      " */",
      "",
      "public class <span class=\"symbol-31 highlightable\">HelloWorld</span> {",
      "}"
    );
  }

  @Test
  public void should_decorate_source_with_multiple_decoration_strategies() throws Exception {

    HtmlSourceDecorator sourceDecorator = new HtmlSourceDecorator(getMyBatis());

    List<String> decoratedSource = (List<String>) sourceDecorator.getDecoratedSourceAsHtml(13L);

    assertThat(decoratedSource).containsExactly(
      "<span class=\"cppd\">/*</span>",
      "<span class=\"cppd\"> * Header</span>",
      "<span class=\"cppd\"> */</span>",
      "",
      "<span class=\"k\">public </span><span class=\"k\">class </span><span class=\"symbol-31 highlightable\">HelloWorld</span> {",
      "  <span class=\"k\">public</span> <span class=\"k\">void</span> <span class=\"symbol-58 highlightable\">foo</span>() {",
      "  }",
      "  <span class=\"k\">public</span> <span class=\"k\">void</span> <span class=\"symbol-84 highlightable\">bar</span>() {",
      "    <span class=\"symbol-58 highlightable\">foo</span>();",
      "  }",
      "}"
    );
  }

  @Test
  public void should_not_query_sources_if_no_snapshot_data() throws Exception {

    SnapshotSourceDao snapshotSourceDao = mock(SnapshotSourceDao.class);
    SnapshotDataDao snapshotDataDao = mock(SnapshotDataDao.class);

    HtmlSourceDecorator sourceDecorator = new HtmlSourceDecorator(snapshotSourceDao, snapshotDataDao);

    sourceDecorator.getDecoratedSourceAsHtml(14L);

    verify(snapshotDataDao, times(1)).selectSnapshotData(14L);
    verify(snapshotSourceDao, times(0)).selectSnapshotSource(14L);
  }
}
