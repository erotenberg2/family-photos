ActiveAdmin.register_page "Dashboard", namespace: :family do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    
    # Include the family import JavaScript
    content_for :head do
      javascript_include_tag 'family_import'
    end
    
    columns do
      column do
        panel "Real-Time Activity Monitor" do
          div id: "progress-monitor", style: "min-height: 200px;" do
            div id: "progress-status", style: "text-align: center; padding: 20px; color: #666;" do
              "Loading activity status..."
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
            link_to "Import Media", '#', 
                    class: "btn btn-primary", 
                    style: "display: inline-block; margin: 10px; padding: 10px 20px; background: #007cba; color: white; text-decoration: none; border-radius: 4px;",
                    onclick: "openImportPopup(); return false;",
                    'data-import-popup-url': import_media_popup_family_media_path
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
        function updateProgressStatus() {
          fetch('/family/progress')
            .then(response => response.json())
            .then(data => {
              const statusDiv = document.getElementById('progress-status');
              
              if (data.status === 'success') {
                const uploadSessions = data.data.upload_sessions || [];
                const postProcessingBatches = data.data.post_processing_batches || [];
                
                let html = '';
                
                // Show upload sessions
                if (uploadSessions.length > 0) {
                  uploadSessions.forEach(session => {
                    const processedFiles = session.uploaded_files + session.skipped_files + session.failed_files;
                    const progress = session.total_files > 0 ? 
                      Math.round((processedFiles / session.total_files) * 100) : 0;
                    
                    html += `
                      <div style="background: #e8f4fd; padding: 12px; border-radius: 6px; border-left: 4px solid #007cba; margin-bottom: 10px;">
                        <div style="font-size: 14px; font-weight: bold; color: #007cba; margin-bottom: 6px;">
                          📤 Upload Session ${session.status === 'completed' ? '(Completed)' : '(Active)'}
                        </div>
                        <div style="margin-bottom: 8px; font-size: 12px;">
                          <strong>${session.uploaded_files}</strong> uploaded, 
                          <strong>${session.skipped_files}</strong> skipped, 
                          <strong>${session.failed_files}</strong> failed of 
                          <strong>${session.total_files}</strong> total
                        </div>
                        <div style="background: #ddd; height: 6px; border-radius: 3px; overflow: hidden;">
                          <div style="background: #28a745; height: 100%; width: ${progress}%; transition: width 0.3s ease;"></div>
                        </div>
                        ${session.current_file ? `<div style="font-size: 11px; color: #666; margin-top: 4px;">Current: ${session.current_file}</div>` : ''}
                      </div>
                    `;
                  });
                }
                
                // Show post-processing batches
                if (postProcessingBatches.length > 0) {
                  postProcessingBatches.forEach(batch => {
                    const progress = batch.total_media > 0 ? 
                      Math.round(((batch.processed_media + batch.failed_media) / batch.total_media) * 100) : 0;
                    
                    html += `
                      <div style="background: #fff3cd; padding: 12px; border-radius: 6px; border-left: 4px solid #ffc107; margin-bottom: 10px;">
                        <div style="font-size: 14px; font-weight: bold; color: #856404; margin-bottom: 6px;">
                          ⚙️ Post-Processing ${batch.status === 'completed' ? '(Completed)' : '(Active)'}
                        </div>
                        <div style="margin-bottom: 8px; font-size: 12px;">
                          <strong>${batch.processed_media}</strong> processed, 
                          <strong>${batch.failed_media}</strong> failed of 
                          <strong>${batch.total_media}</strong> total
                        </div>
                        <div style="background: #ddd; height: 6px; border-radius: 3px; overflow: hidden;">
                          <div style="background: #ffc107; height: 100%; width: ${progress}%; transition: width 0.3s ease;"></div>
                        </div>
                        ${batch.current_medium ? `<div style="font-size: 11px; color: #666; margin-top: 4px;">Current: ${batch.current_medium}</div>` : ''}
                      </div>
                    `;
                  });
                }
                
                if (html === '') {
                  html = `
                    <div style="text-align: center; padding: 20px; color: #28a745;">
                      <div style="font-size: 18px; margin-bottom: 8px;">✅</div>
                      <div style="font-weight: bold;">No Active Operations</div>
                      <div style="font-size: 12px; color: #666; margin-top: 5px;">
                        Ready to import media files
                      </div>
                    </div>
                  `;
                }
                
                statusDiv.innerHTML = html;
              } else {
                statusDiv.innerHTML = `
                  <div style="text-align: center; padding: 20px; color: #dc3545;">
                    <div style="font-weight: bold;">Error loading progress</div>
                    <div style="font-size: 12px; color: #666; margin-top: 5px;">
                      ${data.message || 'Unknown error'}
                    </div>
                  </div>
                `;
              }
            })
            .catch(error => {
              const statusDiv = document.getElementById('progress-status');
              statusDiv.innerHTML = `
                <div style="text-align: center; padding: 20px; color: #dc3545;">
                  <div style="font-weight: bold;">Connection Error</div>
                  <div style="font-size: 12px; color: #666; margin-top: 5px;">
                    Unable to fetch progress data
                  </div>
                </div>
              `;
            });
        }
        
        // Update immediately and then every 2 seconds
        updateProgressStatus();
        setInterval(updateProgressStatus, 2000);
      }
    end

  end # content
end 