diff --git a/lib/project_razor/logging.rb b/lib/project_razor/logging.rb
index 7c2a87c..a5d725c 100644
--- a/lib/project_razor/logging.rb
+++ b/lib/project_razor/logging.rb
@@ -30,7 +30,7 @@ module ProjectRazor::Logging
 
     def get_log_level
       if ENV['RAZOR_LOG_LEVEL'] == nil
-        return 3
+        return LOG_LEVEL
       end
       ENV['RAZOR_LOG_LEVEL'].to_i
     end
