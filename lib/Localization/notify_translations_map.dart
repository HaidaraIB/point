/// Push / email notification copy — merged into [AppTranslations] for en/ar parity.
const Map<String, String> notifyTranslationsEn = {
  'notify.department_unknown': 'Unknown department',
  'notify.email.task_title': 'Task title',
  'notify.email.task': 'Task',
  'notify.email.status': 'Status',
  'notify.email.new_status': 'New status',
  'notify.email.employee': 'Employee',
  'notify.email.client': 'Client',
  'notify.email.content': 'Content',
  'notify.email.department': 'Department',
  'notify.email.content_type': 'Content type',
  'notify.email.publish_date': 'Publish date',
  'notify.email.platform': 'Platform',
  'notify.email.date': 'Date',
  'notify.email.time': 'Time',
  'notify.email.post': 'Post',
  'notify.email.reference': 'Reference',
  'notify.email.update_type': 'Update type',
  'notify.email.changed_by': 'Changed by',
  'notify.email.due_date': 'Due date',
  'notify.email.start_date': 'Start date',
  'notify.email.priority': 'Priority',
  'notify.email.edit_message': 'Edit request',
  'notify.email.rejection_reason': 'Rejection reason',
  'notify.email.requested_by': 'Requested by',
  'notify.email.rejected_by': 'Rejected by',
  'notify.email.comment_preview': 'Comment',
  'notify.email.attachment_count': 'Attachments',
  'notify.email.added_by': 'Added by',
  'notify.email.extension_reason': 'Extension reason',
  'notify.email.denial_note': 'Denial note',
  'notify.email.notification_time': 'Notification time',
  'notify.email.recipient': 'Recipient',
  'notify.email.recipient_id': 'Recipient ID',
  'notify.unknown_actor': 'Unknown',
  'notify.email.state_reopened': 'Reopened',
  'notify.emp.assigned.title': 'You have been assigned a new task',
  'notify.emp.assigned.action':
      'Open the task and start work according to priority.',
  'notify.emp.due_soon.title': '⏳ Delivery deadline approaching',
  'notify.emp.due_soon.body': 'Little time left — @title',
  'notify.emp.due_soon.action':
      'Make sure you complete delivery by the set time.',
  'notify.emp.due_soon_1h.title': '⏳ About one hour to deadline',
  'notify.emp.due_soon_1h.body': '@title',
  'notify.emp.due_soon_1h.action':
      'Finish and submit before the deadline.',
  'notify.emp.followup.title': '⏳ Follow-up: task still waiting',
  'notify.emp.followup.body': '@title — act before the deadline.',
  'notify.emp.followup.action': 'Please take action at the nearest time.',
  'notify.emp.start_reminder.title': '⏰ Start reminder',
  'notify.emp.start_reminder.body': 'Not started yet — @title',
  'notify.emp.start_reminder.action':
      'Open the task and begin work without further delay.',
  'notify.emp.stale_update.title': '📝 Task update needed',
  'notify.emp.stale_update.body': 'No update on «@title» for a while.',
  'notify.emp.stale_update.action':
      'Update the task status or complete it.',
  'notify.emp.overdue.title': '❌ Overdue task',
  'notify.emp.overdue.body': 'Deadline passed: @title',
  'notify.emp.overdue.action': 'Please handle the task immediately.',
  'notify.emp.no_progress_yet.title': '📌 Still no recorded progress',
  'notify.emp.no_progress_yet.body': '@title — log your progress.',
  'notify.emp.no_progress_yet.action':
      'Record progress after you start work.',
  'notify.emp.milestone.on_track.title': '👍 25% milestone',
  'notify.emp.milestone.on_track.body': '@title — about a quarter done.',
  'notify.emp.milestone.on_track.action': 'Keep up the good work.',
  'notify.emp.milestone.halfway.title': '👍 50% — halfway there',
  'notify.emp.milestone.halfway.body': '@title',
  'notify.emp.milestone.halfway.action': 'Good pace — continue.',
  'notify.emp.milestone.near_end.title': '🎯 75% — almost there',
  'notify.emp.milestone.near_end.body': '@title — three quarters done.',
  'notify.emp.milestone.near_end.action': 'Push to complete.',
  'notify.emp.milestone.finished.title': '✅ 100% — task progress complete',
  'notify.emp.milestone.finished.body': '@title',
  'notify.emp.milestone.finished.action': 'Great work.',
  'notify.mgr.progress_updated.title': '📊 Progress percentage updated',
  'notify.mgr.progress_updated.body': '@name — @title: @pct%',
  'notify.mgr.progress_updated.action':
      'Review progress from the task board.',
  'notify.mgr.no_action.title': '⚠️ No action on task',
  'notify.mgr.no_action.body':
      '«@title» — @name has not taken action yet.',
  'notify.mgr.no_action.action': 'Follow up with the assignee.',
  'notify.mgr.stalled.title': '⛔ Progress stalled',
  'notify.mgr.stalled.body':
      'No new progress on «@title» (@name) for some time.',
  'notify.mgr.stalled.action': 'Please follow up on the task.',
  'notify.emp.edit_mgmt.title': 'Edit requested on the task by management',
  'notify.emp.edit_mgmt.action':
      'Apply the requested changes and resubmit.',
  'notify.emp.rejected.title': 'Task rejected',
  'notify.emp.rejected.body':
      'The task (@title) was rejected by management',
  'notify.emp.rejected.action':
      'Review the rejection reason and update the task.',
  'notify.emp.reopened.title': 'Task reopened due to notes',
  'notify.emp.reopened.action': 'Review the notes and continue processing.',
  'notify.emp.attachments.title': 'New files attached to the task',
  'notify.emp.attachments.action':
      'Review the attached files and update your work.',
  'notify.emp.new_comment.title': 'New comment on your task',
  'notify.emp.new_comment.body': '@name added a comment on «@title»',
  'notify.emp.new_comment.action': 'Open the task and read the comment.',
  'notify.emp.status_changed.title': 'Task status updated',
  'notify.emp.status_changed.body':
      'Task status changed for @title to @label by @by',
  'notify.emp.status_changed.action':
      'Open the task to continue based on the latest status.',
  'notify.mgr.received.title':
      'Employee accepted the task; it is now in progress',
  'notify.mgr.received.body': 'Employee: @name — Task: @title',
  'notify.mgr.received.action': 'You can track progress from the task board.',
  'notify.mgr.attendance_submitted.title': 'Attendance submitted',
  'notify.mgr.attendance_submitted.body': '@name — @action (pending approval)',
  'notify.mgr.attendance_submitted.action': 'Open attendance log to review.',
  'notify.mgr.completed.title':
      'Employee completed the task — please review and approve',
  'notify.mgr.completed.body': 'Employee: @name — Task: @title',
  'notify.mgr.completed.action':
      'Review the deliverables and approve or request changes.',
  'notify.admin.supervisor_escalated.title':
      'Supervisor sent a task for your review',
  'notify.admin.supervisor_escalated.body':
      'Supervisor: @supervisor — Task: @title',
  'notify.admin.supervisor_escalated.action':
      'Open the task and approve or reject.',
  'notify.mgr.edited.title': 'Employee added a comment',
  'notify.mgr.edited.body':
      '@name added a comment on task «@title»',
  'notify.mgr.edited.action':
      'Review the comment and the task details.',
  'notify.mgr.edited.detail_value': 'New comment',
  'notify.mgr.edited_files.title': 'Employee added an attachment',
  'notify.mgr.edited_files.body':
      '@name added an attachment to task «@title»',
  'notify.mgr.edited_files.action':
      'Review the attachment and the task details.',
  'notify.mgr.edited_files.detail_value': 'New attachment',
  'notify.mgr.edited_both.title': 'Employee added a comment or attachment',
  'notify.mgr.edited_both.body':
      '@name updated task «@title» with a new comment and/or attachment',
  'notify.mgr.edited_both.action':
      'Review the new comment, attachments, and task details.',
  'notify.mgr.edited_both.detail_value': 'Comment / attachment',
  'notify.mgr.content_submitted.title':
      'New content submitted for review by client',
  'notify.mgr.content_submitted.body': 'Client: @name — Content: @title',
  'notify.mgr.content_submitted.action':
      'Review the content and take appropriate action.',
  'notify.mgr.overdue.title': 'Overdue task',
  'notify.mgr.overdue.body': 'Past deadline: @title — Employee: @name',
  'notify.mgr.overdue.action': 'Follow up on the delay and update the timeline.',
  'notify.mgr.new_task_dept.title': 'New task created in department @dept',
  'notify.mgr.new_task_dept.action': 'Assign the task and monitor execution.',
  'notify.mgr.client_notes.title': 'Notes received from client',
  'notify.mgr.client_notes.body': 'Client: @name — Content: @title',
  'notify.mgr.client_notes.action':
      'Address the client notes and resubmit.',
  'notify.mgr.client_approved.title': 'Client approved the content',
  'notify.mgr.client_approved.body': 'Client: @name — Content: @title',
  'notify.mgr.client_approved.action':
      'Approved — you can proceed to the next step.',
  'notify.mgr.deadline_extension.title': 'Deadline extension requested',
  'notify.mgr.deadline_extension.body': 'Task: @title — Employee: @name',
  'notify.mgr.deadline_extension.action':
      'Review the request in the task details.',
  'notify.emp.deadline_extension.title': 'Deadline extension update',
  'notify.emp.deadline_extension.approved.body':
      'Approved: @title — New due: @date',
  'notify.emp.deadline_extension.denied.body': 'Denied: @title',
  'notify.emp.deadline_extension.action': 'Open the task for details.',
  'notify.client.pending.title': '@type uploaded, pending your approval',
  'notify.client.pending.body': 'Please review and approve or request changes',
  'notify.client.pending.action': 'Open the content and make your decision.',
  'notify.client.pending_24h.title':
      'Content waiting for your review for over 24 hours',
  'notify.client.pending_24h.action':
      'Review the content to avoid scheduling delays.',
  'notify.client.approval_confirmed.title':
      'Thank you! Your approval was recorded',
  'notify.client.approval_confirmed.body':
      'Your approval was saved successfully',
  'notify.client.approval_confirmed.action':
      'Thank you — we will proceed automatically.',
  'notify.client.approval_confirmed.email_status': 'Approved',
  'notify.client.edits_done.title': 'The changes you requested are done',
  'notify.client.edits_done.action': 'Please review the updated version.',
  'notify.client.updated.title': 'Updated content pending your approval',
  'notify.client.updated.action':
      'Review and confirm approval or request more changes.',
  'notify.client.scheduled.title':
      'Content scheduled for publication on @date',
  'notify.client.scheduled.action':
      'Make sure everything is ready before publish time.',
  'notify.publish.added.title': 'New client content added on a platform',
  'notify.publish.added.body':
      'Client: @client — Platform: @platform — @date at @time',
  'notify.publish.added.action': 'Prepare for publishing on time.',
  'notify.publish.edit_req.title': 'Client requested changes to the content',
  'notify.publish.edit_req.action':
      'Apply the requested changes and resend.',
  'notify.publish.approved.title': 'Client approved the content',
  'notify.publish.approved.body': 'Client: @name — Content: @title',
  'notify.publish.approved.action': 'Approved — proceed to publishing.',
  'notify.publish.rejected.title': 'Content rejected by client',
  'notify.publish.rejected.body': 'Content: @title — Client: @name',
  'notify.publish.rejected.action':
      'Review the rejection and address the notes.',
  'notify.publish.one_hour.title':
      'Reminder: scheduled post will be published within 15 minutes',
  'notify.publish.one_hour.action':
      'Ensure the post is ready before publishing.',
  'notify.publish.today_not_confirmed.title':
      'Alert: post scheduled for today is not confirmed yet',
  'notify.publish.today_not_confirmed.body': 'Post: @ref',
  'notify.publish.today_not_confirmed.action':
      'Confirm the post or update its status immediately.',
  'notify.publish.no_posts_tomorrow.title':
      'Alert: no posts scheduled for tomorrow',
  'notify.publish.no_posts_tomorrow.body': 'Client account: @name',
  'notify.publish.no_posts_tomorrow.action':
      'Plan content for the next day.',
  'notify.publish.published.title':
      'Post published successfully on @platform',
  'notify.publish.published.action':
      'Document the publication and add the link if available.',
  'notify.publish.link_added.title': 'Post link added',
  'notify.publish.link_added.action':
      'Review the link and verify it is correct.',
  'notify.publish.notes_after.title': 'Notes entered after publishing',
  'notify.publish.notes_after.action': 'Review the notes and take action.',
  'notify.publish.cancelled.title':
      'Scheduled post cancelled per client request',
  'notify.publish.cancelled.action':
      'Update the schedule and notify stakeholders.',
  'notify.admin.promo_changed.title': 'Content promotion status changed',
  'notify.admin.promo_changed.body': '@title — to: @label',
  'notify.admin.promo_changed.action': 'Monitor the impact on the campaign.',
  'notify.admin.status_changed.title': 'Content status changed',
  'notify.admin.status_changed.body': '@title — to: @label — by: @by',
  'notify.admin.status_changed.action': 'Review the new content status.',
  'notify.promo.new_published.title':
      'New published content for client — add it to the ad campaign',
  'notify.promo.new_published.body': 'Client: @name — Content: @title',
  'notify.promo.new_published.action':
      'Add it to the appropriate advertising campaign.',
  'notify.battery_opt.title': 'Battery optimization',
  'notify.battery_opt.body':
      'To reduce delayed push notifications, allow this app to run without battery restrictions when the system asks.',
  'notify.battery_opt.later': 'Not now',
  'notify.battery_opt.open_settings': 'Continue',
};

const Map<String, String> notifyTranslationsAr = {
  'notify.department_unknown': 'قسم غير محدد',
  'notify.email.task_title': 'عنوان المهمة',
  'notify.email.task': 'المهمة',
  'notify.email.status': 'الحالة',
  'notify.email.new_status': 'الحالة الجديدة',
  'notify.email.employee': 'الموظف',
  'notify.email.client': 'العميل',
  'notify.email.content': 'المحتوى',
  'notify.email.department': 'القسم',
  'notify.email.content_type': 'نوع المحتوى',
  'notify.email.publish_date': 'تاريخ النشر',
  'notify.email.platform': 'المنصة',
  'notify.email.date': 'التاريخ',
  'notify.email.time': 'الوقت',
  'notify.email.post': 'المنشور',
  'notify.email.reference': 'المرجع',
  'notify.email.update_type': 'نوع التحديث',
  'notify.email.changed_by': 'تم التغيير بواسطة',
  'notify.email.due_date': 'موعد التسليم',
  'notify.email.start_date': 'تاريخ البدء',
  'notify.email.priority': 'الأولوية',
  'notify.email.edit_message': 'نص طلب التعديل',
  'notify.email.rejection_reason': 'سبب الرفض',
  'notify.email.requested_by': 'طُلب بواسطة',
  'notify.email.rejected_by': 'رُفض بواسطة',
  'notify.email.comment_preview': 'التعليق',
  'notify.email.attachment_count': 'المرفقات',
  'notify.email.added_by': 'أُضيف بواسطة',
  'notify.email.extension_reason': 'سبب التمديد',
  'notify.email.denial_note': 'ملاحظة الرفض',
  'notify.email.notification_time': 'وقت الإشعار',
  'notify.email.recipient': 'المستلم',
  'notify.email.recipient_id': 'معرف المستلم',
  'notify.unknown_actor': 'غير معروف',
  'notify.email.state_reopened': 'أعيد فتحها',
  'notify.emp.assigned.title': 'تم تعيينك على مهمة جديدة',
  'notify.emp.assigned.action':
      'يرجى فتح المهمة والبدء بالتنفيذ حسب الأولوية.',
  'notify.emp.due_soon.title': '⏳ اقتراب موعد التسليم',
  'notify.emp.due_soon.body': 'بقي وقت قليل — @title',
  'notify.emp.due_soon.action':
      'تأكد من إنجاز المهمة وتسليمها في الوقت المحدد.',
  'notify.emp.due_soon_1h.title': '⏳ متبقي حوالي ساعة على التسليم',
  'notify.emp.due_soon_1h.body': '@title',
  'notify.emp.due_soon_1h.action':
      'أكمل التسليم قبل انتهاء الموعد.',
  'notify.emp.followup.title': '⏳ متابعة: المهمة ما زالت بانتظار إجراء',
  'notify.emp.followup.body': '@title — يرجى التصرف قبل الموعد.',
  'notify.emp.followup.action':
      'نرجو اتخاذ إجراء في أقرب وقت.',
  'notify.emp.start_reminder.title': '⏰ تذكير بالبدء',
  'notify.emp.start_reminder.body': 'لم تبدأ بعد — @title',
  'notify.emp.start_reminder.action':
      'افتح المهمة وابدأ العمل دون تأخير.',
  'notify.emp.stale_update.title': '📝 تحديث المهمة مطلوب',
  'notify.emp.stale_update.body': 'لم يُحدَّث «@title» منذ فترة.',
  'notify.emp.stale_update.action':
      'حدّث حالة المهمة أو أكملها.',
  'notify.emp.overdue.title': '❌ مهمة متأخرة',
  'notify.emp.overdue.body': 'تجاوز موعد التسليم: @title',
  'notify.emp.overdue.action':
      'يرجى معالجة المهمة فوراً.',
  'notify.emp.no_progress_yet.title': '📌 لا يزال بلا تقدم مسجّل',
  'notify.emp.no_progress_yet.body': '@title — سجّل تقدمك.',
  'notify.emp.no_progress_yet.action':
      'سجّل التقدم بعد أن تبدأ العمل.',
  'notify.emp.milestone.on_track.title': '👍 عتبة 25٪',
  'notify.emp.milestone.on_track.body': '@title — حوالي ربع المسار.',
  'notify.emp.milestone.on_track.action': 'استمر على هذا المنوال.',
  'notify.emp.milestone.halfway.title': '👍 50٪ — منتصف الطريق',
  'notify.emp.milestone.halfway.body': '@title',
  'notify.emp.milestone.halfway.action': 'إيقاع جيد — تابع.',
  'notify.emp.milestone.near_end.title': '🎯 75٪ — اقتربت من النهاية',
  'notify.emp.milestone.near_end.body': '@title — ثلاثة أرباع المسار.',
  'notify.emp.milestone.near_end.action': 'اضغط لإنهاء المهمة.',
  'notify.emp.milestone.finished.title': '✅ 100٪ — اكتمل تقدّم المهمة',
  'notify.emp.milestone.finished.body': '@title',
  'notify.emp.milestone.finished.action': 'عمل رائع.',
  'notify.mgr.progress_updated.title': '📊 تحديث نسبة الإنجاز',
  'notify.mgr.progress_updated.body': '@name — @title: @pct%',
  'notify.mgr.progress_updated.action':
      'راجع التقدم من لوحة المهام.',
  'notify.mgr.no_action.title': '⚠️ لم يتخذ موظف إجراءً على المهمة',
  'notify.mgr.no_action.body':
      '«@title» — @name لم يبدأ بعد تاريخ البدء.',
  'notify.mgr.no_action.action': 'تابع مع المكلّف.',
  'notify.mgr.stalled.title': '⛔ توقف التقدم',
  'notify.mgr.stalled.body':
      'لا تسجيل لتقدم جديد على «@title» (@name) منذ فترة.',
  'notify.mgr.stalled.action': 'يرجى متابعة المهمة.',
  'notify.emp.edit_mgmt.title': 'طلب تعديل على المهمة من قبل الإدارة',
  'notify.emp.edit_mgmt.action':
      'يرجى تنفيذ التعديلات المطلوبة ثم إعادة التسليم.',
  'notify.emp.rejected.title': 'مهمة مرفوضة',
  'notify.emp.rejected.body': 'تم رفض المهمة (@title) من قبل الإدارة',
  'notify.emp.rejected.action': 'يرجى مراجعة سبب الرفض وتحديث المهمة.',
  'notify.emp.reopened.title': 'تم إعادة فتح مهمة لوجود ملاحظات',
  'notify.emp.reopened.action': 'يرجى مراجعة الملاحظات واستكمال المعالجة.',
  'notify.emp.attachments.title': 'تم إرفاق ملفات جديدة بالمهمة',
  'notify.emp.attachments.action':
      'يرجى الاطلاع على الملفات المرفقة وتحديث العمل.',
  'notify.emp.new_comment.title': 'تعليق جديد على مهمتك',
  'notify.emp.new_comment.body': 'أضاف @name تعليقاً على «@title»',
  'notify.emp.new_comment.action': 'افتح المهمة واطّلع على التعليق.',
  'notify.emp.status_changed.title': 'تم تحديث حالة المهمة',
  'notify.emp.status_changed.body':
      'تم تغيير حالة المهمة @title إلى @label بواسطة @by',
  'notify.emp.status_changed.action':
      'افتح المهمة للمتابعة حسب الحالة الجديدة.',
  'notify.mgr.received.title':
      'تم استلام المهمة من قبل الموظف وهي قيد التنفيذ الآن',
  'notify.mgr.received.body': 'الموظف: @name — المهمة: @title',
  'notify.mgr.received.action': 'يمكن متابعة التقدم عبر لوحة المهام.',
  'notify.mgr.attendance_submitted.title': 'تم تسجيل حضور',
  'notify.mgr.attendance_submitted.body': '@name — @action (بانتظار الموافقة)',
  'notify.mgr.attendance_submitted.action': 'افتح سجل الحضور للمراجعة.',
  'notify.mgr.completed.title':
      'قام الموظف بإنجاز المهمة يرجى الاطلاع والموافقة',
  'notify.mgr.completed.body': 'الموظف: @name — المهمة: @title',
  'notify.mgr.completed.action':
      'يرجى مراجعة المخرجات واعتماد المهمة أو طلب تعديل.',
  'notify.admin.supervisor_escalated.title':
      'أحال المشرف مهمة للمراجعة',
  'notify.admin.supervisor_escalated.body':
      'المشرف: @supervisor — المهمة: @title',
  'notify.admin.supervisor_escalated.action':
      'يرجى فتح المهمة والموافقة أو الرفض.',
  'notify.mgr.edited.title': 'قام الموظف بإضافة تعليق',
  'notify.mgr.edited.body':
      'أضاف @name تعليقاً على المهمة «@title»',
  'notify.mgr.edited.action':
      'يرجى الاطلاع على التعليق ومراجعة تفاصيل المهمة.',
  'notify.mgr.edited.detail_value': 'تعليق جديد',
  'notify.mgr.edited_files.title': 'قام الموظف بإضافة مرفق',
  'notify.mgr.edited_files.body':
      'أضاف @name مرفقاً إلى المهمة «@title»',
  'notify.mgr.edited_files.action':
      'يرجى مراجعة المرفق وتفاصيل المهمة.',
  'notify.mgr.edited_files.detail_value': 'مرفق جديد',
  'notify.mgr.edited_both.title':
      'قام الموظف بإضافة تعليق أو مرفق',
  'notify.mgr.edited_both.body':
      'حدّث @name المهمة «@title» بتعليق و/أو مرفق جديد',
  'notify.mgr.edited_both.action':
      'يرجى مراجعة التعليق والمرفقات وتفاصيل المهمة.',
  'notify.mgr.edited_both.detail_value': 'تعليق / مرفق',
  'notify.mgr.content_submitted.title':
      'تم رفع محتوى جديد للمراجعة من قبل العميل',
  'notify.mgr.content_submitted.body': 'العميل: @name — المحتوى: @title',
  'notify.mgr.content_submitted.action':
      'يرجى مراجعة المحتوى واتخاذ الإجراء المناسب.',
  'notify.mgr.overdue.title': 'مهمة متأخرة',
  'notify.mgr.overdue.body': 'تجاوزت موعد التسليم: @title — الموظف: @name',
  'notify.mgr.overdue.action':
      'يرجى متابعة سبب التأخير وتحديث الخطة الزمنية.',
  'notify.mgr.new_task_dept.title': 'تم إنشاء مهمة جديدة في @dept',
  'notify.mgr.new_task_dept.action': 'يرجى توزيع المهمة ومتابعة التنفيذ.',
  'notify.mgr.client_notes.title': 'استلام ملاحظات من العميل',
  'notify.mgr.client_notes.body': 'العميل: @name — المحتوى: @title',
  'notify.mgr.client_notes.action':
      'يرجى معالجة ملاحظات العميل وإعادة الإرسال.',
  'notify.mgr.client_approved.title': 'العميل قام بالموافقة على المحتوى',
  'notify.mgr.client_approved.body': 'العميل: @name — المحتوى: @title',
  'notify.mgr.client_approved.action':
      'تمت الموافقة، يمكن المتابعة للمرحلة التالية.',
  'notify.mgr.deadline_extension.title': 'طلب تمديد موعد تسليم',
  'notify.mgr.deadline_extension.body': 'المهمة: @title — الموظف: @name',
  'notify.mgr.deadline_extension.action':
      'راجع الطلب من تفاصيل المهمة.',
  'notify.emp.deadline_extension.title': 'تحديث طلب تمديد التسليم',
  'notify.emp.deadline_extension.approved.body':
      'تمت الموافقة: @title — الموعد الجديد: @date',
  'notify.emp.deadline_extension.denied.body': 'تم الرفض: @title',
  'notify.emp.deadline_extension.action': 'افتح المهمة للتفاصيل.',
  'notify.client.pending.title': 'تم رفع @type بانتظار موافقتك',
  'notify.client.pending.body': 'يرجى الاطلاع والموافقة أو طلب التعديل',
  'notify.client.pending.action': 'يرجى فتح المحتوى واتخاذ القرار المناسب.',
  'notify.client.pending_24h.title':
      'لديك محتوى بانتظار المراجعة منذ أكثر من 24 ساعة',
  'notify.client.pending_24h.action':
      'يرجى مراجعة المحتوى لتجنب تأخر الجدولة.',
  'notify.client.approval_confirmed.title':
      'شكراً! تمت الموافقة على التصميم من قبلك',
  'notify.client.approval_confirmed.body': 'تم تسجيل موافقتك بنجاح',
  'notify.client.approval_confirmed.action':
      'شكراً لتعاونك، سيتم المتابعة تلقائياً.',
  'notify.client.approval_confirmed.email_status': 'تمت الموافقة',
  'notify.client.edits_done.title': 'تم تنفيذ التعديلات التي طلبتها',
  'notify.client.edits_done.action': 'يرجى مراجعة النسخة المعدلة.',
  'notify.client.updated.title': 'محتوى جديد محدث بانتظار الموافقة',
  'notify.client.updated.action':
      'يرجى الاطلاع وتأكيد الموافقة أو طلب تعديل إضافي.',
  'notify.client.scheduled.title':
      'تم جدولة المحتوى ليُنشر بتاريخ @date',
  'notify.client.scheduled.action':
      'يرجى التأكد من الجاهزية قبل موعد النشر.',
  'notify.publish.added.title': 'تمت إضافة محتوى جديد للعميل على منصة',
  'notify.publish.added.body':
      'العميل: @client — المنصة: @platform — @date الساعة @time',
  'notify.publish.added.action': 'يرجى متابعة تجهيز النشر حسب الموعد.',
  'notify.publish.edit_req.title': 'قام العميل بطلب تعديل على المحتوى',
  'notify.publish.edit_req.action':
      'يرجى تنفيذ التعديل المطلوب وإعادة الإرسال.',
  'notify.publish.approved.title': 'وافق العميل على المحتوى',
  'notify.publish.approved.body': 'العميل: @name — المحتوى: @title',
  'notify.publish.approved.action':
      'تمت الموافقة، يمكن المتابعة لخطوة النشر.',
  'notify.publish.rejected.title': 'تم رفض المحتوى من قبل العميل',
  'notify.publish.rejected.body': 'المحتوى: @title — العميل: @name',
  'notify.publish.rejected.action': 'يرجى مراجعة الرفض ومعالجة الملاحظات.',
  'notify.publish.one_hour.title':
      'تذكير: لديك منشور مجدول سيتم نشره خلال ١٥ دقيقة',
  'notify.publish.one_hour.action':
      'يرجى التأكد من جاهزية المنشور قبل النشر.',
  'notify.publish.today_not_confirmed.title':
      'تنبيه: منشور مجدول اليوم ولم يتم تأكيده بعد',
  'notify.publish.today_not_confirmed.body': 'المنشور: @ref',
  'notify.publish.today_not_confirmed.action':
      'يرجى تأكيد المنشور أو تعديل حالته فوراً.',
  'notify.publish.no_posts_tomorrow.title':
      'تنبيه: لا توجد منشورات مجدولة ليوم غد',
  'notify.publish.no_posts_tomorrow.body': 'حساب العميل: @name',
  'notify.publish.no_posts_tomorrow.action':
      'يرجى التخطيط لجدولة منشورات اليوم التالي.',
  'notify.publish.published.title':
      'تم نشر المنشور بنجاح على منصة @platform',
  'notify.publish.published.action':
      'يرجى توثيق النشر وإضافة الرابط إن توفر.',
  'notify.publish.link_added.title': 'تمت إضافة رابط المنشور',
  'notify.publish.link_added.action': 'يرجى مراجعة الرابط والتأكد من صحته.',
  'notify.publish.notes_after.title': 'تم إدخال الملاحظات بعد النشر',
  'notify.publish.notes_after.action':
      'يرجى مراجعة الملاحظات وتنفيذ المطلوب.',
  'notify.publish.cancelled.title':
      'تم إلغاء نشر منشور مجدول بناءً على طلب العميل',
  'notify.publish.cancelled.action':
      'يرجى تحديث الجدولة وإبلاغ الأطراف المعنية.',
  'notify.admin.promo_changed.title': 'تم تغيير حالة المحتوى',
  'notify.admin.promo_changed.body': '@title — إلى: @label',
  'notify.admin.promo_changed.action':
      'يرجى متابعة انعكاس الحالة على الحملة.',
  'notify.admin.status_changed.title': 'تم تغيير حالة المحتوى',
  'notify.admin.status_changed.body': '@title — إلى: @label — بواسطة: @by',
  'notify.admin.status_changed.action': 'يرجى مراجعة حالة المحتوى الجديدة.',
  'notify.promo.new_published.title':
      'محتوى منشور جديد للعميل يرجى الاطلاع وإضافته للحملة الإعلانية',
  'notify.promo.new_published.body': 'العميل: @name — المحتوى: @title',
  'notify.promo.new_published.action':
      'يرجى إضافته للحملة الإعلانية المناسبة.',
  'notify.battery_opt.title': 'تحسين البطارية',
  'notify.battery_opt.body':
      'لتقليل تأخر الإشعارات، اسمح للتطبيق باستثناء من تحسين البطارية عند ظهور طلب النظام.',
  'notify.battery_opt.later': 'ليس الآن',
  'notify.battery_opt.open_settings': 'متابعة',
};
