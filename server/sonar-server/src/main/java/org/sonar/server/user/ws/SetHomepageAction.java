/*
 * SonarQube
 * Copyright (C) 2009-2017 SonarSource SA
 * mailto:info AT sonarsource DOT com
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
package org.sonar.server.user.ws;

import org.sonar.api.server.ws.Request;
import org.sonar.api.server.ws.Response;
import org.sonar.api.server.ws.WebService;
import org.sonar.db.DbClient;
import org.sonar.db.DbSession;
import org.sonar.db.user.UserDto;
import org.sonar.server.component.ComponentFinder;
import org.sonar.server.user.UserSession;

import static com.google.common.base.Preconditions.checkState;
import static org.apache.commons.lang.StringUtils.isBlank;
import static org.sonar.server.ws.WsUtils.checkFoundWithOptional;
import static org.sonarqube.ws.Users.CurrentWsResponse.HomepageType.MY_ISSUES;
import static org.sonarqube.ws.Users.CurrentWsResponse.HomepageType.MY_PROJECTS;
import static org.sonarqube.ws.Users.CurrentWsResponse.HomepageType.ORGANIZATION;
import static org.sonarqube.ws.Users.CurrentWsResponse.HomepageType.PROJECT;

public class SetHomepageAction implements UsersWsAction {

  static final String PARAM_TYPE = "type";
  static final String PARAM_VALUE = "value";
  static final String ACTION = "set_homepage";

  private final UserSession userSession;
  private final DbClient dbClient;
  private final ComponentFinder componentFinder;

  public SetHomepageAction(UserSession userSession, DbClient dbClient, ComponentFinder componentFinder) {
    this.userSession = userSession;
    this.dbClient = dbClient;
    this.componentFinder = componentFinder;
  }

  @Override
  public void define(WebService.NewController controller) {
    WebService.NewAction action = controller.createAction(ACTION)
      .setPost(true)
      .setDescription("Set Homepage of current user.<br> Requires authentication.")
      .setSince("7.0")
      .setHandler(this);

    action.createParam(PARAM_TYPE)
      .setDescription("Type of the requested page")
      .setRequired(true)
      .setPossibleValues(HomepageTypes.keys());

    action.createParam(PARAM_VALUE)
      .setDescription("Additional information to filter the page (project or organization key)")
      .setExampleValue("my-project-key");

  }

  @Override
  public void handle(Request request, Response response) throws Exception {
    userSession.checkLoggedIn();

    String type = request.mandatoryParam(PARAM_TYPE);
    String value = request.param(PARAM_VALUE);

    if (PROJECT.toString().equals(type) && isBlank(value)) {
      throw new IllegalArgumentException("type PROJECT requires a mandatory project key");
    }

    if (ORGANIZATION.toString().equals(type) && isBlank(value)) {
      throw new IllegalArgumentException("type ORGANIZATION requires a mandatory project key");
    }

    String userLogin = userSession.getLogin();

    String uuid = null;

    try (DbSession dbSession = dbClient.openSession(false)) {

      UserDto userDto = dbClient.userDao().selectActiveUserByLogin(dbSession, userLogin);
      checkState(userDto != null, "User login '%s' cannot be found", userLogin);

      if (PROJECT.toString().equals(type)) {
        uuid = componentFinder.getByKey(dbSession, value).uuid();
      }

      if (ORGANIZATION.toString().equals(type)) {
        uuid = checkFoundWithOptional(dbClient.organizationDao().selectByKey(dbSession, value), "No organizationDto with key '%s'", value).getUuid();
      }

      if ((MY_PROJECTS.toString().equals(type) || MY_ISSUES.toString().equals(type)) && value != null) {
        throw new IllegalArgumentException("value parameter must be null when type = [MY_PROJECTS | MY_ISSUES]");
      }

      userDto.setHomepageType(type);
      userDto.setHomepageValue(uuid);

      dbClient.userDao().update(dbSession, userDto);
      dbSession.commit();
    }

    response.noContent();
  }
}
