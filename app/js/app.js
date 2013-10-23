define(
  ['angular',
   'require',
   'underscore',
   'config',
   'angular-ui-router',
   'services/decisionProblem',
   'services/workspace',
   'services/taskDependencies',
   'foundation.dropdown',
   'foundation.tooltip',
   'controllers',
   'components'],
  function(angular, require, _, Config) {
    var dependencies = [
      'ui.router',
      'elicit.problem-resource',
      'elicit.workspace',
      'elicit.components',
      'elicit.controllers',
      'elicit.taskDependencies'];
    var app = angular.module('elicit', dependencies);

    app.run(['$rootScope', function($rootScope) {
      $rootScope.$on('$viewContentLoaded', function () {
        $(document).foundation();
      });

      // from http://stackoverflow.com/questions/16952244/what-is-the-best-way-to-close-a-dropdown-in-zurb-foundation-4-when-clicking-on-a
      $('.f-dropdown').click(function() {
        if ($(this).hasClass('open')) {
          $('[data-dropdown="'+$(this).attr('id')+'"]').trigger('click');
        }
      });

      $rootScope.$safeApply = function($scope, fn) {
        var phase = $scope.$root.$$phase;
        if(phase == '$apply' || phase == '$digest') {
          this.$eval(fn);
        }
        else {
          this.$apply(fn);
        }
      };
      $rootScope.$on('patavi.error', function(e, message) {
        $rootScope.$safeApply($rootScope, function() {
          $rootScope.error = message;
        });
      });
    }]);
    app.constant('Tasks', Config.tasks);


    app.controller("ChooseProblemController", ['$scope', '$injector', function($scope, $injector) {
      require(['controllers/' + 'chooseProblem'], function(controller) {
        $injector.invoke(controller, this, { '$scope' : $scope });
     });
    }]);

    // example url: /#/workspaces/<id>/scenarios/<id>/<taskname>
    app.config(['Tasks', '$stateProvider', '$urlRouterProvider', function(Tasks, $stateProvider, $urlRouterProvider) {

      var baseTemplatePath = "app/views/";
      _.each(Tasks.available, function(task) {
      var camelCase = function (str) { return str.replace(/-([a-z])/g, function (g) { return g[1].toUpperCase(); }); };
        require(['controllers/' + camelCase(task.id)], function(controller) {
        app.controller(task.controller, controller);
          var templateUrl = baseTemplatePath + task.templateUrl;
          $stateProvider.state(task.id, {
            url: '/workspaces/:workspaceId/scenarios/:scenarioId/' + task.id,
            templateUrl: templateUrl,
            resolve: {
              currentWorkspace: function($stateParams, Workspaces) {
                return Workspaces.get($stateParams.workspaceId);
              },
              currentScenario: function($stateParams, currentWorkspace) {
                return currentWorkspace.getScenario($stateParams.scenarioId);
              }
            },
            controller: controller
          });
        });
      });

      // Default route
      $stateProvider.state('choose-problem',
                           { url: '/choose-problem',
                             templateUrl: baseTemplatePath + 'chooseProblem.html',
                             controller: "ChooseProblemController" });
      $urlRouterProvider.otherwise('/choose-problem');
    }]);

    return app;
  });
