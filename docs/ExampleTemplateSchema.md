* Modules
  * Shared
    * Should primarily be resource templates, generalized for use in other templates.
  * Workload
    * Should typically be shared workloads with customized parameters for a workload.
* Workloads
  * Shared
    * Should primarily be workloads used by other deployments to simplify architecture.
    * Examples of `shared` workloads would be Databases, App Service Plans, and more, as long as they are used by other (typically `application`) workloads.
    * Can rely on `system` workloads.
  * Application
    * `Application` workloads are those that are directly interacted with by users.
    * Can rely on `shared` AND `system` workloads.
  * System
    * System workloads should be foundational, and provide low-level functionality to other workloads.
    * System workloads should **NOT** depend on any other workload.
  * One workload template for each use-case or objective.
  * Some templates are baseline workloads required for others, and some are platform templates.
  * Workloads like the Universal Print Connector require hybrid networking.