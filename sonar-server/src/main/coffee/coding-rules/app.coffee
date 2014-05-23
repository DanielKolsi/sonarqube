requirejs.config
  baseUrl: "#{baseUrl}/js"

  paths:
    'backbone': 'third-party/backbone'
    'backbone.marionette': 'third-party/backbone.marionette'
    'handlebars': 'third-party/handlebars'
    'jquery.mockjax': 'third-party/jquery.mockjax'

  shim:
    'backbone.marionette':
      deps: ['backbone']
      exports: 'Marionette'
    'backbone':
      exports: 'Backbone'
    'handlebars':
      exports: 'Handlebars'


requirejs [
  'backbone', 'backbone.marionette',

  'coding-rules/layout',
  'coding-rules/router',

  # views
  'coding-rules/views/header-view',
  'coding-rules/views/actions-view',
  'coding-rules/views/filter-bar-view',
  'coding-rules/views/coding-rules-list-view',
  'coding-rules/views/coding-rules-bulk-change-view',
  'coding-rules/views/coding-rules-quality-profile-activation-view',
  'coding-rules/views/coding-rules-bulk-change-dropdown-view'
  'coding-rules/views/coding-rules-facets-view'

  # filters
  'navigator/filters/base-filters',
  'navigator/filters/choice-filters',
  'navigator/filters/string-filters',
  'navigator/filters/date-filter-view',
  'coding-rules/views/filters/quality-profile-filter-view',
  'coding-rules/views/filters/inheritance-filter-view',
  'coding-rules/views/filters/activation-filter-view',
  'coding-rules/views/filters/characteristic-filter-view',
  'coding-rules/views/filters/repository-filter-view',
  'coding-rules/views/filters/tag-filter-view',

  'coding-rules/mockjax',
  'common/handlebars-extensions'
], (
  Backbone, Marionette,

  CodingRulesLayout,
  CodingRulesRouter,

  # views
  CodingRulesHeaderView,
  CodingRulesActionsView,
  CodingRulesFilterBarView,
  CodingRulesListView,
  CodingRulesBulkChangeView,
  CodingRulesQualityProfileActivationView,
  CodingRulesBulkChangeDropdownView
  CodingRulesFacetsView

  # filters
  BaseFilters,
  ChoiceFilters,
  StringFilterView,
  DateFilterView,
  QualityProfileFilterView,
  InheritanceFilterView,
  ActivationFilterView,
  CharacteristicFilterView,
  RepositoryFilterView,
  TagFilterView
) ->

  # Create a generic error handler for ajax requests
  jQuery.ajaxSetup
    error: (jqXHR) ->
      text = jqXHR.responseText
      errorBox = jQuery('.modal-error')
      if jqXHR.responseJSON?.errors?
        text = _.pluck(jqXHR.responseJSON.errors, 'msg').join '. '
      if errorBox.length > 0
        errorBox.show().text text
      else
        alert text


  # Add html class to mark the page as navigator page
  jQuery('html').addClass('navigator-page coding-rules-page');


  # Create an Application
  App = new Marionette.Application


  App.getQuery =  ->
    @filterBarView.getQuery()


  App.restoreSorting = ->


  App.storeQuery = (query, sorting) ->
    if sorting
      _.extend query,
        s: sorting.sort
        asc: '' + sorting.asc
    queryString = _.map query, (v, k) -> "#{k}=#{encodeURIComponent(v)}"
    @router.navigate queryString.join('|'), replace: true



  App.fetchList = (firstPage, fromFacets) ->
    query = @getQuery()
    fetchQuery = _.extend { p: @pageIndex, ps: 25, facets: !fromFacets }, query

    if @codingRulesFacetsView
      _.extend fetchQuery, @codingRulesFacetsView.getQuery()

    if @codingRules.sorting
      _.extend fetchQuery,
          s: @codingRules.sorting.sort,
          asc: @codingRules.sorting.asc

    @storeQuery query, @codingRules.sorting

    # Optimize requested fields
    _.extend fetchQuery, f: 'name,lang,status'

    if @codingRulesListView
      scrollOffset = jQuery('.navigator-results')[0].scrollTop
    else
      scrollOffset = 0

    @layout.showSpinner 'resultsRegion'
    @layout.showSpinner 'facetsRegion' unless fromFacets || !firstPage
    jQuery.ajax
      url: "#{baseUrl}/api/rules/search"
      data: fetchQuery
    .done (r) =>
      _.map(r.rules, (rule) ->
        rule.language = App.languages[rule.lang]
      )

      if firstPage
        @codingRules.reset r.rules
      else
        @codingRules.add r.rules
      @codingRules.paging =
        total: r.total
        pageIndex: r.p
        pageSize: r.ps
        pages: 1 + (r.total / r.ps)

      @codingRulesListView = new CodingRulesListView
        app: @
        collection: @codingRules
      @layout.resultsRegion.show @codingRulesListView
      @codingRulesListView.selectFirst()

      unless firstPage
        jQuery('.navigator-results')[0].scrollTop = scrollOffset

      unless fromFacets
        @codingRulesFacetsView = new CodingRulesFacetsView
          app: @
          collection: new Backbone.Collection r.facets
        @layout.facetsRegion.show @codingRulesFacetsView

      @layout.onResize()



  App.facetLabel = (property, value) ->
    return value unless App.facetPropertyToLabels[property]
    App.facetPropertyToLabels[property](value)


  App.fetchFirstPage = (fromFacets = false) ->
    @pageIndex = 1
    App.fetchList true, fromFacets


  App.fetchNextPage = (fromFacets = false) ->
    if @pageIndex < @codingRules.paging.pages
      @pageIndex++
      App.fetchList false, fromFacets


  App.getQualityProfile = ->
    value = @qualityProfileFilter.get('value')
    if value? && value.length == 1 then value[0] else null


  # Construct layout
  App.addInitializer ->
    @layout = new CodingRulesLayout app: @
    jQuery('#content').append @layout.render().el
    @layout.onResize()


  # Construct header
  App.addInitializer ->
    @codingRulesHeaderView = new CodingRulesHeaderView app: @
    @layout.headerRegion.show @codingRulesHeaderView


  # Define coding rules
  App.addInitializer ->
    @codingRules = new Backbone.Collection
    @codingRules.sorting = sort: 'CREATED_AT', asc: false


  # Construct status bar
  App.addInitializer ->
    @codingRulesActionsView = new CodingRulesActionsView
      app: @
      collection: @codingRules
    @layout.actionsRegion.show @codingRulesActionsView


  # Construct bulk change views
  App.addInitializer ->
    @codingRulesBulkChangeView = new CodingRulesBulkChangeView app: @
    @codingRulesBulkChangeDropdownView = new CodingRulesBulkChangeDropdownView app: @


  # Construct quality profile activation view
  App.addInitializer ->
    @codingRulesQualityProfileActivationView = new CodingRulesQualityProfileActivationView app: @


  # Define filters
  App.addInitializer ->
    @filters = new BaseFilters.Filters

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.name'
      property: 'q'
      type: StringFilterView

    @languageFilter =  new BaseFilters.Filter
      name: t 'coding_rules.filters.language'
      property: 'languages'
      type: ChoiceFilters.ChoiceFilterView
      choices: @languages
    @filters.add @languageFilter

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.severity'
      property: 'severities'
      type: ChoiceFilters.ChoiceFilterView
      choices:
        'BLOCKER': t 'severity.BLOCKER'
        'CRITICAL': t 'severity.CRITICAL'
        'MAJOR': t 'severity.MAJOR'
        'MINOR': t 'severity.MINOR'
        'INFO': t 'severity.INFO'
      choiceIcons:
        'BLOCKER': 'severity-blocker'
        'CRITICAL': 'severity-critical'
        'MAJOR': 'severity-major'
        'MINOR': 'severity-minor'
        'INFO': 'severity-info'

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.tag'
      property: 'tags'
      type: TagFilterView

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.characteristic'
      property: 'debt_characteristics'
      type: CharacteristicFilterView
      choices: @characteristics
      multiple: false

    @qualityProfileFilter = new BaseFilters.Filter
      name: t 'coding_rules.filters.quality_profile'
      property: 'qprofile'
      type: QualityProfileFilterView
      app: @
      choices: @qualityProfiles
      multiple: false
    @filters.add @qualityProfileFilter

    @activationFilter = new BaseFilters.Filter
      name: t 'coding_rules.filters.activation'
      property: 'activation'
      type: ActivationFilterView
      enabled: false
      optional: false
      multiple: false
      qualityProfileFilter: @qualityProfileFilter
      choices:
        true: t 'coding_rules.filters.activation.active'
        false: t 'coding_rules.filters.activation.inactive'
    @filters.add @activationFilter

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.availableSince'
      property: 'availableSince'
      type: DateFilterView
      enabled: false
      optional: true

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.inheritance'
      property: 'inheritance'
      type: InheritanceFilterView
      enabled: false
      optional: true
      multiple: false
      qualityProfileFilter: @qualityProfileFilter
      choices:
        'not_inhertited': t 'coding_rules.filters.inheritance.not_inherited'
        'inhertited': t 'coding_rules.filters.inheritance.inherited'
        'overriden': t 'coding_rules.filters.inheritance.overriden'

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.repository'
      property: 'repositories'
      type: RepositoryFilterView
      enabled: false
      optional: true
      app: @
      choices: @repositories

    @filters.add new BaseFilters.Filter
      name: t 'coding_rules.filters.status'
      property: 'statuses'
      type: ChoiceFilters.ChoiceFilterView
      enabled: false
      optional: true
      choices: @statuses


    @filterBarView = new CodingRulesFilterBarView
      app: @
      collection: @filters,
      extra: sort: '', asc: false
    @layout.filtersRegion.show @filterBarView


  # Start router
  App.addInitializer ->
    @router = new CodingRulesRouter app: @
    Backbone.history.start()


  # Call app before start the application
  appXHR = jQuery.ajax
    url: "#{baseUrl}/api/rules/app"
  .done (r) ->
    App.appState = new Backbone.Model
    App.state = new Backbone.Model
    App.canWrite = r.canWrite
    App.qualityProfiles = r.qualityprofiles
    App.languages = r.languages
    App.repositories = r.repositories
    App.statuses = r.statuses
    App.characteristics = r.characteristics

    App.facetPropertyToLabels =
      'languages': (value) -> App.languages[value]
      'repositories': (value) ->
        repo = _.findWhere(App.repositories, key: value)
        repo.name + ' - ' + App.languages[repo.language]

  # Message bundles
  l10nXHR = window.requestMessages()

  jQuery.when(appXHR, l10nXHR).done ->
      # Remove the initial spinner
      jQuery('#coding-rules-page-loader').remove()

      # Start the application
      App.start()
