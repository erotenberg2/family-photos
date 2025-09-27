ActiveAdmin.register_page "Dashboard", namespace: :family do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    
    columns do
      column do
        panel "Media Import Status" do
          div id: "job-monitor", style: "min-height: 120px;" do
            div id: "job-status", style: "text-align: center; padding: 20px; color: #666;" do
              "Loading job status..."
            end
          end
        end
        
        panel "Recent Media" do
          ul do
            Medium.includes(:mediable).order(created_at: :desc).limit(10).map do |medium|
              li do
                case medium.medium_type
                when 'photo'
                  link_to medium.mediable&.title || medium.original_filename || "Untitled", family_photo_path(medium.mediable)
                else
                  link_to medium.original_filename || "Untitled", family_medium_path(medium)
                end
                span " (#{medium.medium_type}) - #{time_ago_in_words(medium.created_at)} ago", style: "color: #999; font-size: 12px;"
              end
            end
          end
        end
      end
      
      column do
        panel "Media Statistics" do
          table do
            tr do
              td "Total Media Files:"
              td Medium.count, style: "font-weight: bold;"
            end
            tr do
              td "Photos:"
              td Medium.where(medium_type: 'photo').count, style: "font-weight: bold;"
            end
            tr do
              td "Storage Used:"
              td number_to_human_size(Medium.sum(:file_size) || 0), style: "font-weight: bold;"
            end
            tr do
              td "Media Added Today:"
              td Medium.where('created_at >= ?', Date.current.beginning_of_day).count, style: "font-weight: bold;"
            end
            tr do
              td "Media This Week:"
              td Medium.where('created_at >= ?', 1.week.ago).count, style: "font-weight: bold;"
            end
          end
        end
        
        panel "Quick Actions" do
          div style: "text-align: center;" do
            link_to "Import Media", import_media_family_media_path, 
                    class: "btn btn-primary", 
                    style: "display: inline-block; margin: 10px; padding: 10px 20px; background: #007cba; color: white; text-decoration: none; border-radius: 4px;"
            br
            link_to "View All Media", family_media_path, 
                    class: "btn btn-secondary",
                    style: "display: inline-block; margin: 5px; padding: 8px 16px; background: #6c757d; color: white; text-decoration: none; border-radius: 4px;"
            link_to "View Photos", family_photos_path, 
                    class: "btn btn-secondary",
                    style: "display: inline-block; margin: 5px; padding: 8px 16px; background: #6c757d; color: white; text-decoration: none; border-radius: 4px;"
          end
        end
      end
    end

    script do
      raw %{
        function updateJobStatus() {
          fetch('/family/job_status')
            .then(response => response.json())
            .then(data => {
              const statusDiv = document.getElementById('job-status');
              
              if (data.processing_jobs > 0 || data.queued_jobs > 0) {
                const total = data.processing_jobs + data.queued_jobs;
                statusDiv.innerHTML = `
                  <div style="background: #e8f4fd; padding: 15px; border-radius: 6px; border-left: 4px solid #007cba;">
                    <div style="font-size: 16px; font-weight: bold; color: #007cba; margin-bottom: 8px;">
                      📁 Media Import in Progress
                    </div>
                    <div style="margin-bottom: 10px;">
                      <strong>${data.processing_jobs}</strong> job(s) processing, 
                      <strong>${data.queued_jobs}</strong> job(s) waiting
                    </div>
                    <div style="background: #007cba; height: 8px; border-radius: 4px; position: relative; overflow: hidden;">
                      <div style="background: #28a745; height: 100%; width: ${data.processing_jobs > 0 ? 50 : 0}%; transition: width 0.3s ease;"></div>
                    </div>
                    <div style="font-size: 12px; color: #666; margin-top: 5px;">
                      Processing since ${data.oldest_job_time || 'unknown'}
                    </div>
                  </div>
                `;
              } else if (data.completed_jobs > 0) {
                statusDiv.innerHTML = `
                  <div style="background: #d4edda; padding: 15px; border-radius: 6px; border-left: 4px solid #28a745;">
                    <div style="font-size: 16px; font-weight: bold; color: #28a745; margin-bottom: 8px;">
                      ✅ All Media Imported
                    </div>
                    <div style="color: #155724;">
                      <strong>${data.completed_jobs}</strong> job(s) completed recently
                    </div>
                  </div>
                `;
              } else {
                statusDiv.innerHTML = `
                  <div style="background: #f8f9fa; padding: 15px; border-radius: 6px; border: 1px solid #dee2e6;">
                    <div style="font-size: 16px; color: #6c757d; margin-bottom: 8px;">
                      💤 No Active Jobs
                    </div>
                    <div style="color: #6c757d; font-size: 14px;">
                      Ready to import media
                    </div>
                  </div>
                `;
              }
            })
            .catch(error => {
              console.error('Error fetching job status:', error);
              document.getElementById('job-status').innerHTML = `
                <div style="color: #dc3545; text-align: center;">
                  ⚠️ Unable to load job status
                </div>
              `;
            });
        }
        
        // Update immediately and then every second
        updateJobStatus();
        setInterval(updateJobStatus, 1000);
      }
    end

  end # content
end 