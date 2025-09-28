ActiveAdmin.register UploadLog do
  
  # Permitted parameters
  permit_params :batch_id, :session_id, :user_agent, :total_files_selected, 
                :files_imported, :files_skipped, :files_failed, :user_id

  # Index page configuration
  index do
    selectable_column
    id_column
    
    column "Status", sortable: false do |log|
      status_tag log.status, class: log.status_color
    end
    
    column "Files", sortable: :total_files_selected do |log|
      parts = []
      parts << "#{log.files_imported} imported" if log.files_imported > 0
      parts << "#{log.files_skipped} skipped" if log.files_skipped > 0
      parts << "#{log.files_failed} failed" if log.files_failed > 0
      
      if parts.empty?
        "0/#{log.total_files_selected}"
      else
        "#{parts.join(', ')} (#{log.total_files_selected} total)"
      end
    end
    
    column "Success Rate", sortable: false do |log|
      "#{log.success_rate}%"
    end
    
    column "Duration", sortable: false do |log|
      log.session_duration_human
    end
    
    column "Browser", sortable: false do |log|
      log.browser_name
    end
    
    column :user do |log|
      link_to log.user.email, admin_user_path(log.user) if log.user
    end
    
    column :batch_id do |log|
      truncate(log.batch_id, length: 8)
    end
    
    column :created_at do |log|
      log.created_at.strftime("%m/%d %H:%M")
    end
    
    actions
  end

  # Filters
  filter :completion_status, as: :select, collection: [['Incomplete', 'incomplete'], ['Complete', 'complete'], ['Interrupted', 'interrupted']]
  filter :user
  filter :created_at
  filter :total_files_selected
  filter :files_imported
  filter :files_skipped
  filter :files_failed
  filter :batch_id

  # Scopes for quick filtering
  scope :all, default: true
  scope :completed
  scope :in_progress
  scope :successful
  scope :with_errors
  scope :interrupted
  scope :complete_status
  scope :incomplete_status
  scope :recent

  # Show page configuration with admin-specific features
  show do
    # Add CSS for better table formatting
    content_for :head do
      raw <<~CSS
        <style>
          .upload-session-table {
            width: 100%;
            margin: 20px 0;
          }
          .upload-session-table th {
            background: #f8f9fa;
            font-weight: bold;
            padding: 12px;
            border: 1px solid #dee2e6;
            text-align: left;
            width: 200px;
          }
          .upload-session-table td {
            padding: 12px;
            border: 1px solid #dee2e6;
            word-break: break-word;
          }
          .file-list-table {
            width: 100%;
            margin: 10px 0;
            font-size: 14px;
          }
          .file-list-table th {
            background: #e9ecef;
            padding: 8px;
            border: 1px solid #dee2e6;
            font-weight: bold;
          }
          .file-list-table td {
            padding: 8px;
            border: 1px solid #dee2e6;
          }
          .admin-stats {
            background: #e3f2fd;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
          }
          .status-imported { color: #28a745; font-weight: bold; }
          .status-skipped { color: #dc3545; font-weight: bold; }
          .file-size { text-align: right; }
        </style>
      CSS
    end

    # System Statistics Panel (Admin-specific)
    panel "System Upload Statistics" do
      div class: 'admin-stats' do
        total_sessions = UploadLog.count
        completed_sessions = UploadLog.completed.count
        successful_sessions = UploadLog.successful.count
        total_files_processed = UploadLog.sum(:total_files_selected)
        total_files_imported = UploadLog.sum(:files_imported)
        system_success_rate = total_files_processed > 0 ? (total_files_imported.to_f / total_files_processed * 100).round(1) : 0
        
        h4 "System Overview"
        ul do
          li "Total Upload Sessions: #{number_with_delimiter(total_sessions)}"
          li "Completed Sessions: #{number_with_delimiter(completed_sessions)}"
          li "Successful Sessions: #{number_with_delimiter(successful_sessions)}"
          li "Total Files Processed: #{number_with_delimiter(total_files_processed)}"
          li "Total Files Imported: #{number_with_delimiter(total_files_imported)}"
          li "System Success Rate: #{system_success_rate}%"
        end
      end
    end

    # Session Overview Panel
    panel "Upload Session Details" do
      table_for([resource], class: 'upload-session-table') do
        column("Status") do |log|
          status_class = "status-#{log.status.downcase.gsub(' ', '-')}"
          content_tag :span, log.status, class: status_class
        end
        column("Batch ID") { |log| log.batch_id }
        column("Session ID") { |log| log.session_id }
        column("User") { |log| link_to log.user.email, admin_user_path(log.user) }
        column("Browser") { |log| log.browser_name }
        column("User Agent") { |log| truncate(log.user_agent, length: 60) if log.user_agent }
        column("Started At") { |log| log.session_started_at&.strftime("%Y-%m-%d %H:%M:%S") || "—" }
        column("Completed At") { |log| log.session_completed_at&.strftime("%Y-%m-%d %H:%M:%S") || "—" }
        column("Duration") { |log| log.session_duration_human }
      end
    end

    # Performance Statistics Panel
    panel "Performance Statistics" do
      table_for([resource], class: 'upload-session-table') do
        column("Total Files Selected") { |log| number_with_delimiter(log.total_files_selected) }
        column("Files Imported") { |log| number_with_delimiter(log.files_imported) }
        column("Files Skipped") { |log| number_with_delimiter(log.files_skipped) }
        column("Files Failed") { |log| number_with_delimiter(log.files_failed) }
        column("Success Rate") { |log| "#{log.success_rate}%" }
        column("Average File Size") do |log|
          if log.files_data.any?
            avg_size = log.files_data.sum { |f| f['file_size'] || 0 } / log.files_data.count
            number_to_human_size(avg_size)
          else
            "—"
          end
        end
      end
    end

    # Imported Files Panel with Admin Links
    if resource.imported_files.any?
      panel "Successfully Imported Files (#{resource.imported_files.count})" do
        table class: 'file-list-table' do
          thead do
            tr do
              th "Filename"
              th "Client Path"
              th "Size"
              th "Type"
              th "Medium ID"
              th "Actions"
            end
          end
          tbody do
            resource.imported_files.each do |file_data|
              tr do
                td file_data['filename']
                td do
                  if file_data['client_file_path'].present?
                    content_tag :code, file_data['client_file_path'], style: "font-size: 11px; background: #f8f9fa; padding: 2px 4px; border-radius: 3px;"
                  else
                    "—"
                  end
                end
                td number_to_human_size(file_data['file_size']), class: 'file-size'
                td file_data['content_type']
                td file_data['medium_id'] || "—"
                td do
                  links = []
                  if file_data['medium_id']
                    links << link_to("View Medium", admin_medium_path(file_data['medium_id']), class: 'btn btn-sm btn-primary')
                  end
                  if file_data['mediable_id'] && file_data['mediable_type'] == 'Photo'
                    links << link_to("View Photo", admin_photo_path(file_data['mediable_id']), class: 'btn btn-sm btn-secondary')
                  end
                  raw(links.join(' '))
                end
              end
            end
          end
        end
      end
    end

    # Skipped Files Panel with Detailed Analysis
    if resource.skipped_files.any?
      panel "Skipped Files Analysis (#{resource.skipped_files.count})" do
        # Group by skip reason for admin analysis
        skip_reasons = resource.skipped_files.group_by { |f| f['skip_reason'] }
        
        skip_reasons.each do |reason, files|
          h5 "#{reason} (#{files.count} files)"
          table class: 'file-list-table' do
            thead do
              tr do
                th "Filename"
                th "Client Path"
                th "Size"
                th "Type"
              end
            end
            tbody do
              files.each do |file_data|
                tr do
                  td file_data['filename']
                  td do
                    if file_data['client_file_path'].present?
                      content_tag :code, file_data['client_file_path'], style: "font-size: 11px; background: #f8f9fa; padding: 2px 4px; border-radius: 3px;"
                    else
                      "—"
                    end
                  end
                  td number_to_human_size(file_data['file_size']), class: 'file-size'
                  td file_data['content_type']
                end
              end
            end
          end
        end
      end
    end

    # Raw JSONB Data Panel (Admin debugging)
    panel "Raw File Data (JSONB)" do
      pre JSON.pretty_generate(resource.files_data), style: "background: #f8f9fa; padding: 15px; border-radius: 5px; font-size: 12px; max-height: 400px; overflow-y: auto;"
    end
  end

  # Admin batch actions
  batch_action :delete_old_logs, confirm: "Are you sure you want to delete these upload logs?" do |ids|
    UploadLog.where(id: ids).destroy_all
    redirect_to collection_path, notice: "#{ids.count} upload logs deleted."
  end

  batch_action :export_failed_sessions, confirm: "Export failed sessions for analysis?" do |ids|
    # TODO: Implement CSV export of failed sessions
    redirect_to collection_path, notice: "Export functionality coming soon!"
  end

end
