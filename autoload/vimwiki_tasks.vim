" TODO: update tasks on opening
" TODO: support task without time but with #TW identifier
" TODO: update existing tasks in TW when writing (including completed!)
" TODO: how to handle deleted tasks?
" TODO: hide the uuid's
" TODO: default params for task

function! vimwiki_tasks#write()
    let l:defaults = vimwiki_tasks#get_defaults()
    let l:i = 1
    while l:i <= line('$')
        let l:line = getline(l:i)
        " check if this is a line with an open task with a due date
        if match(l:line, '\v\* \[[^X]\].*\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)') != -1
            let l:task = vimwiki_tasks#create_task(l:line, l:defaults)
            " add the task if it does not have a uuid
            if l:task.uuid == ""
                call system(l:task.task_cmd.' add '.l:task.description.' '.l:task.task_meta)
                " find the id and the uuid of the newly created task
                let l:id = substitute(system("task newest limit:1 rc.verbose=nothing rc.color=off rc.defaultwidth=999 rc.report.newest.columns=id rc.report.newest.labels=ID"), "\n", "", "")
                " TODO: check for valid id and successful task creation before
                " continuing?
                let l:uuid = substitute(system("task ".l:id." uuid"), "\n", "", "")
                " add the uuid to the line
                call setline(l:i, l:line." #".l:uuid)
                " annotate the task to reference the vimwiki file
                let l:cmd = 'task '.l:id.' annotate vimwiki:'.expand('%:p')
                call system(l:cmd)
            " see if we need to update the task in TW
            else
                let l:tw_task = vimwiki_tasks#load_task(l:task.uuid)
                " compare:
                "   - description
                "   - due
                "   - project
                "   - status (XXX: not yet, because we are only dealing with open tasks here)
                "   - tags? (XXX: are updated but not compared)
                if l:task.description !=# l:tw_task.description || l:task.due !=# l:tw_task.due || l:task.project !=# l:defaults.project
                    let l:cmd = l:task.task_cmd.' uuid:'.l:task.uuid.' modify '.l:task.description.' '.l:task.task_meta
                    call system(l:cmd)
                endif
            endif
        endif
        let l:i += 1
    endwhile
endfunction

function! vimwiki_tasks#get_defaults()
    let l:defaults = {'project': ''}
    let l:i = 1
    while l:i <= 10
        let l:line = getline(l:i)
        let l:project = matchstr(l:line, '\v\%\%\s*Project:\s*\zs(\w+)')
        if l:project != ""
            let l:defaults.project = l:project
        endif
        let l:i +=1
    endwhile
    return l:defaults
endfunction

function! vimwiki_tasks#create_task(line, defaults)
    let l:task = vimwiki_tasks#empty_task()
    " create the task
    let l:match = matchlist(a:line, '\v\* \[[^X]\]\s+(.*)\s*')
    let l:task.description = l:match[1]
    " construct the task creation command and create
    let l:task.task_cmd = 'task'
    let l:task.task_meta = ''
    " add a project if necessary
    if has_key(a:defaults, 'project')
        let l:task.task_meta .= ' project:'.a:defaults.project
    endif
    " add due date if available
    let l:due = matchlist(a:line, '\v\((\d{4}-\d\d-\d\d)( (\d\d:\d\d))?\)')
    if !empty(l:due)
        let l:task.due_date = l:due[1]
        let l:task.due_time = get(l:due, 3, '00:00')
        if l:task.due_time == ""
            let l:task.due_time = '00:00'
        endif
        " remove date in line
        let l:task.description = substitute(l:task.description, '\v\(\d{4}-\d\d-\d\d( \d\d:\d\d)?\)', "", "")
        " set the due in task_meta
        let l:task.due = l:task.due_date.'T'.l:task.due_time
        let l:task.task_meta .= ' due:'.l:task.due
        " set the dateformat in task_cmd
        let l:task.task_cmd .= ' rc.dateformat=Y-M-DTH:N'
    endif
    " get the uuid from the task if it is there, and remove it from the task description
    let l:task.uuid = matchstr(a:line, '\v#\zs([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')
    if l:task.uuid != ""
        let l:task.description = substitute(l:task.description, '\v#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', "", "")
    endif

    let l:task.description = <SID>Strip(l:task.description)

    return l:task
endfunction

function! vimwiki_tasks#load_task(uuid)
    let l:task = vimwiki_tasks#empty_task()
    let l:cmd = 'task rc.verbose=nothing rc.defaultwidth=999 rc.dateformat.info=Y-M-DTH:N rc.color=off uuid:'.a:uuid.' info | grep "^\(ID\|Description\|Status\|Due\)"'
    let l:result = split(system(l:cmd), '\n')
    for l:result_line in l:result
        let l:match = matchlist(l:result_line, '\v(\w+)\s+(.*)')
        let l:task[tolower(l:match[1])] = l:match[2]
    endfor
    return l:task
endfunction

function! s:Strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! vimwiki_tasks#empty_task()
    return {'id': 0, 'description': '', 'due': '', 'status': '', 'project': ''}
endfunction
