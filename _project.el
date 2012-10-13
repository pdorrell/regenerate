
(load-this-project
 `( (:ruby-executable ,*ruby-1.9-executable*)
    (:ruby-args (,(concat "-I" (concat (project-base-directory) "/lib"))))
    (:run-project-command (ruby-run-file ,(concat (project-base-directory) "lib/regenerate.rb") *rejenner-test-data-file*))
    (:build-function project-compile-with-command)
    (:compile-command "rake")
    ) )

