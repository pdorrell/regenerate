
(load-this-project
 `( (:ruby-executable ,*ruby-1.9-executable*)
    (:run-project-command (ruby-run-file ,(concat (project-base-directory) "rejenner2.rb") *rejenner-test-data-file*))
    ) )

