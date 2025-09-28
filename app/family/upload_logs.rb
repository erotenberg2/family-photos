ActiveAdmin.register UploadLog, namespace: :family do
  
  # Permitted parameters
  permit_params :batch_id, :session_id, :user_agent, :total_files_selected, 
                :files_imported, :files_skipped

  # Index page configuration
  index do
    selectable_column
    
    column "Status", sortable: false do |log|
      status_tag log.status, class: log.status_color
    end
    
    column "Files", sortable: :total_files_selected do |log|
      "#{log.files_imported}/#{log.total_files_selected}"
    end
    
    column "Success RateX", sortable: false do |log|
      "#{log.success_rate}%"
    end
    
    column "Duration", sortable: false do |log|
      log.session_duration_human
    end
    
    column "Browser", sortable: false do |log|
      log.browser_name
    end
    
    column :batch_id do |log|
      truncate(log.batch_id, length: 12)
    end
    
    column :created_at do |log|
      log.created_at.strftime("%m/%d %H:%M")
    end
    
    actions
  end

  # Filters
  filter :completion_status, as: :select, collection: [['Incomplete', 'incomplete'], ['Complete', 'complete'], ['Interrupted', 'interrupted']]
  filter :created_at
  filter :total_files_selected
  filter :files_imported
  filter :files_skipped

  # Scopes for quick filtering
  scope :all, default: true
  scope :completed
  scope :in_progress
  scope :successful
  scope :with_errors
  scope :interrupted
  scope :complete_status
  scope :incomplete_status

  # Show page configuration
  show do
    # Add CSS for better formatting
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
          .status-imported { color: #28a745; font-weight: bold; }
          .status-skipped { color: #dc3545; font-weight: bold; }
          .file-size { text-align: right; }
        </style>
      CSS
    end

    # Session Overview Panel
    panel "Upload Session Overview" do
      table_for([resource], class: 'upload-session-table') do
        column("Status") do |log|
          status_class = "status-#{log.status.downcase.gsub(' ', '-')}"
          content_tag :span, log.status, class: status_class
        end
        column("Batch ID") { |log| log.batch_id }
        column("Session ID") { |log| truncate(log.session_id, length: 20) }
        column("User") { |log| log.user.email }
        column("Browser") { |log| log.browser_name }
        column("Started At") { |log| log.session_started_at&.strftime("%Y-%m-%d %H:%M:%S") || "—" }
        column("Completed At") { |log| log.session_completed_at&.strftime("%Y-%m-%d %H:%M:%S") || "—" }
        column("Duration") { |log| log.session_duration_human }
      end
    end

    # Statistics Panel
    panel "Upload Statistics" do
      table_for([resource], class: 'upload-session-table') do
        column("Total Files Selected") { |log| number_with_delimiter(log.total_files_selected) }
        column("Files Imported") { |log| number_with_delimiter(log.files_imported) }
        column("Files Skipped") { |log| number_with_delimiter(log.files_skipped) }
        column("Success Rate") { |log| "#{log.success_rate}%" }
      end
    end

    # Imported Files Panel
    if resource.imported_files.any?
      panel "Successfully Imported Files (#{resource.imported_files.count})" do
        table class: 'file-list-table' do
          thead do
            tr do
              th "Filename"
              th "Client Path"
              th "Size"
              th "Type"
              th "View"
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
                td do
                  if file_data['medium_id']
                    link_to "View Medium", family_medium_path(file_data['medium_id']), 
                            class: 'btn btn-sm btn-primary'
                  else
                    "—"
                  end
                end
              end
            end
          end
        end
      end
    end

    # Skipped Files Panel
    if resource.skipped_files.any?
      panel "Skipped Files (#{resource.skipped_files.count})" do
        table class: 'file-list-table' do
          thead do
            tr do
              th "Filename"
              th "Client Path"
              th "Size"
              th "Type"
              th "Skip Reason"
            end
          end
          tbody do
            resource.skipped_files.each do |file_data|
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
                td file_data['skip_reason'] || "Unknown"
              end
            end
          end
        end
      end
    end

    # Technical Details Panel
    panel "Technical Details" do
      table_for([resource], class: 'upload-session-table') do
        column("User Agent") { |log| truncate(log.user_agent, length: 80) if log.user_agent }
        column("Created At") { |log| log.created_at.strftime("%Y-%m-%d %H:%M:%S") }
        column("Updated At") { |log| log.updated_at.strftime("%Y-%m-%d %H:%M:%S") }
      end
    end
  end

end
